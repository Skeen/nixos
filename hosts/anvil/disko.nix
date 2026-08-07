{
  disko,
  pkgs,
  ...
}: {
  # Disko declaratively describes the on-disk layout and can format the disk
  # from this same description, so partitioning is reproducible and lives in
  # the repository rather than in a one-off manual `fdisk`/`cryptsetup` session.
  # https://github.com/nix-community/disko
  #
  # Layout for anvil:
  #   GPT
  #   ├─ ESP        vfat, label BOOT   -> /boot
  #   └─ LUKS2      label luks
  #      └─ crypted (dm-crypt)
  #         └─ btrfs, label nixos
  #            ├─ @root        -> /       (wiped on every boot, see rollback below)
  #            ├─ @root-blank  ->         (pristine empty subvolume, never mounted)
  #            └─ @nix         -> /nix    (holds /nix/persist, survives reboots)
  #
  # Impermanence is achieved by rolling @root back to the pristine @root-blank
  # snapshot in early boot. Everything that must survive a reboot is bind-mounted
  # back in from /nix/persist by the impermanence module (see ./impermanence.nix),
  # exactly as on the other hosts, so only /nix (and /boot) truly persist.

  imports = [
    disko.nixosModules.disko
  ];

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # A whole disk cannot be referenced by filesystem label (labels live on
        # partitions/filesystems, which do not exist yet at format time), so we
        # use the stable by-id path. This is anvil's Samsung 9100 PRO 1TB NVMe.
        device = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_1TB_S7YDNJ0YB02992J";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["fmask=0077" "dmask=0077"];
                extraArgs = ["-n" "BOOT"];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted"; # -> /dev/mapper/crypted, matches the rollback service below
                # cryptsetup defaults to LUKS2, but be explicit about it.
                extraFormatArgs = ["--type" "luks2"];
                # Passphrase supplied at install time via `nixos-anywhere
                # --disk-encryption-keys`; typed in at every boot thereafter.
                passwordFile = "/tmp/luks.key";
                settings = {
                  # SSDs benefit from TRIM being passed through to the disk.
                  # Note: this leaks which blocks are in use; acceptable here.
                  allowDiscards = true;
                  # Skip dm-crypt's read/write workqueues so I/O is processed
                  # on the submitting thread. Reduces latency and lifts
                  # throughput on fast NVMe where the queues are the bottleneck.
                  bypassWorkqueues = true;
                };
                content = {
                  type = "btrfs";
                  extraArgs = ["-L" "nixos" "-f"];
                  subvolumes = {
                    "@root" = {
                      mountpoint = "/";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                    # Pristine, empty subvolume used as the rollback source. It is
                    # created empty by disko and never mounted, so it stays clean.
                    "@root-blank" = {};
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  # /nix holds /nix/persist, which impermanence and agenix read during stage 1
  # boot (e.g. the ssh host key used to decrypt agenix secrets), so it must be
  # mounted before switching to the real root. disko generates the fileSystems
  # entry; we only add neededForBoot on top of it.
  fileSystems."/nix".neededForBoot = true;

  # Use the systemd-based initrd so we can express the rollback as an ordered
  # unit (after LUKS is opened, before the root subvolume is mounted).
  boot.initrd.systemd.enable = true;

  # Roll the root subvolume back to its pristine state on every boot. This is
  # what makes the setup impermanent: any change written directly to / is
  # discarded, and only paths bind-mounted from /nix/persist survive.
  boot.initrd.systemd.services.rollback = {
    description = "Rollback btrfs root subvolume to a pristine state";
    wantedBy = ["initrd.target"];
    # crypted must be unlocked before we can touch the btrfs volume, and the
    # rollback must finish before the real root is mounted.
    after = ["systemd-cryptsetup@crypted.service"];
    before = ["sysroot.mount"];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /mnt

      # Mount the btrfs top-level (subvolid=5), not @root, so we can manage
      # subvolumes directly.
      mount -o subvol=/ /dev/mapper/crypted /mnt

      # Delete any nested subvolumes under @root first (btrfs refuses to delete
      # a subvolume that still contains subvolumes), then @root itself.
      ${pkgs.btrfs-progs}/bin/btrfs subvolume list -o /mnt/@root |
        cut -f9 -d' ' |
        while read subvolume; do
          echo "deleting /$subvolume subvolume..."
          ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "/mnt/$subvolume"
        done
      echo "deleting /@root subvolume..."
      ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /mnt/@root

      echo "restoring blank /@root subvolume..."
      ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot /mnt/@root-blank /mnt/@root

      umount /mnt
    '';
  };

  # Ensure the btrfs userland tooling is present in the initrd for the service
  # above. (Root being btrfs already pulls it in, but be explicit.)
  boot.initrd.systemd.storePaths = ["${pkgs.btrfs-progs}/bin/btrfs"];
}

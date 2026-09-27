{
  disko,
  pkgs,
  ...
}: let
  # A whole disk cannot be referenced by filesystem label (labels live on
  # partitions/filesystems, which do not exist yet at format time), so we use
  # the stable by-id path. This is jester's (Steam Deck LCD) Phison 256GB NVMe.
  # Never pick an mmc device: /dev/mmcblk0 is the microSD card.
  device = "/dev/disk/by-id/nvme-Phison_ESMP256GKB4C3-E13TS_22073M25600597";
in {
  # Disko declaratively describes the on-disk layout and can format the disk
  # from this same description, so partitioning is reproducible and lives in
  # the repository rather than in a one-off manual `fdisk` session.
  # https://github.com/nix-community/disko
  #
  # Layout for jester:
  #   GPT
  #   ├─ ESP        1G, vfat, label BOOT   -> /boot
  #   └─ root       rest, btrfs, label nixos
  #      ├─ @root        -> /          (wiped on every boot, see rollback below)
  #      ├─ @root-blank  ->            (pristine empty subvolume, never mounted)
  #      ├─ @nix         -> /nix       (holds /nix/persist, survives reboots)
  #      └─ @swap        -> /.swapvol  (swapfile)
  #
  # Impermanence is achieved by rolling @root back to the pristine @root-blank
  # snapshot in early boot. Everything that must survive a reboot is bind-mounted
  # back in from /nix/persist by the impermanence module (see ./impermanence.nix),
  # exactly as on the other hosts, so only /nix (and /boot) truly persist.
  #
  # Like golem there is no LUKS layer: the Deck boots unattended into Gaming
  # Mode and has no keyboard to type a passphrase into the initrd. Secrets on
  # disk stay protected by agenix, which encrypts them to the host key rather
  # than to the block device.

  imports = [
    disko.nixosModules.disko
  ];

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        inherit device;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              # Larger than satchel's 512M: Jovian kernel bumps are frequent
              # and each initrd carries the amdgpu firmware. BIOS updates also
              # stage their capsule on the ESP.
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["fmask=0077" "dmask=0077"];
                extraArgs = ["-n" "BOOT"];
              };
            };
            root = {
              size = "100%";
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
                  # Jovian already enables zram, like SteamOS; this adds a
                  # disk-backed swapfile behind it, as SteamOS also does. It
                  # gets its own subvolume because @root is deleted and
                  # re-created on every boot (see rollback below), which would
                  # take a swapfile living there with it. disko creates it once
                  # with `btrfs filesystem mkswapfile` (no COW, no compression).
                  "@swap" = {
                    mountpoint = "/.swapvol";
                    swap.swapfile.size = "8G";
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
  # unit (after the disk shows up, before the root subvolume is mounted).
  boot.initrd.systemd.enable = true;

  # Roll the root subvolume back to its pristine state on every boot. This is
  # what makes the setup impermanent: any change written directly to / is
  # discarded, and only paths bind-mounted from /nix/persist survive.
  boot.initrd.systemd.services.rollback = {
    description = "Rollback btrfs root subvolume to a pristine state";
    wantedBy = ["initrd.target"];
    # On the encrypted hosts this waits for the dm-crypt mapper; here the
    # btrfs volume is on bare disk, so wait for the labelled device itself
    # (systemd escaping: by\x2dlabel). The rollback must finish before the
    # real root is mounted.
    after = ["dev-disk-by\\x2dlabel-nixos.device"];
    requires = ["dev-disk-by\\x2dlabel-nixos.device"];
    before = ["sysroot.mount"];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /mnt

      # Mount the btrfs top-level (subvolid=5), not @root, so we can manage
      # subvolumes directly.
      mount -o subvol=/ /dev/disk/by-label/nixos /mnt

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

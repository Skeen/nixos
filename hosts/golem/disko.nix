{
  disko,
  pkgs,
  ...
}: let
  # A whole disk cannot be referenced by filesystem label (labels live on
  # partitions/filesystems, which do not exist yet at format time), so we use
  # the stable by-id path. This is golem's 40GB Hetzner Cloud virtio-scsi disk.
  device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_120395895";
in {
  # Disko declaratively describes the on-disk layout and can format the disk
  # from this same description, so partitioning is reproducible and lives in
  # the repository rather than in a one-off manual `fdisk` session.
  # https://github.com/nix-community/disko
  #
  # Layout for golem:
  #   GPT
  #   ├─ bios_grub  1M,   no filesystem      (GRUB's core.img)
  #   ├─ boot       512M, ext4, label BOOT   -> /boot
  #   └─ root       rest, btrfs, label nixos
  #      ├─ @root        -> /       (wiped on every boot, see rollback below)
  #      ├─ @root-blank  ->         (pristine empty subvolume, never mounted)
  #      └─ @nix         -> /nix    (holds /nix/persist, survives reboots)
  #
  # Impermanence is achieved by rolling @root back to the pristine @root-blank
  # snapshot in early boot. Everything that must survive a reboot is bind-mounted
  # back in from /nix/persist by the impermanence module (see ./impermanence.nix),
  # exactly as on the other hosts, so only /nix (and /boot) truly persist.
  #
  # Unlike anvil and satchel there is no LUKS layer: golem is a remote cloud
  # server that must come back up unattended after a kernel update, and nobody
  # is there to type a passphrase. Secrets on disk stay protected by agenix,
  # which encrypts them to the host key rather than to the block device.
  #
  # The instance boots via SeaBIOS (legacy BIOS, verified: no /sys/firmware/efi
  # and no EFI variables), so there is no ESP and GRUB goes in the EF02
  # partition. That in turn means /boot cannot live on the rolled-back root
  # subvolume, hence its own partition, mirroring stronghold's label BOOT.

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
            # No filesystem and no mountpoint: GRUB embeds core.img directly
            # into this partition on a GPT/BIOS system.
            bios_grub = {
              priority = 1;
              name = "bios_grub";
              size = "1M";
              type = "EF02";
            };
            boot = {
              priority = 2;
              name = "boot";
              size = "512M";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
                extraArgs = ["-L" "BOOT"];
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
                };
              };
            };
          };
        };
      };
    };
  };

  # Only enable GRUB here: disko points it at the right disk by itself, adding
  # `boot.loader.grub.devices = [device]` for any layout containing an EF02
  # partition. Setting `device` on top of that lands the same disk in
  # mirroredBoots twice, which trips an assertion in the GRUB module.
  boot.loader.grub.enable = true;

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

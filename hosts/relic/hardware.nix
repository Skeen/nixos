{...}: {
  # Storage layout (the same nested layout as granary and coffer):
  #
  #   userdata partition (UFS, /dev/disk/by-partlabel/userdata)
  #   └─ LUKS2, opened by stage-1 as /dev/mapper/relic
  #      └─ ext4 (label NIXOS_SYSTEM; system.img built by Mobile NixOS) -> /nix
  #         ├─ nix/store   -> /nix/store  (bind)
  #         ├─ nix/var     -> /nix/var    (bind)
  #         └─ persist/    (impermanence, see ./impermanence.nix)
  #   tmpfs -> /
  #
  # Mobile NixOS replaces the NixOS initrd with its own stage-1, which mounts
  # every fileSystems entry needed for boot, but silently ignores
  # boot.initrd.postMountCommands and boot.initrd.systemd.*. Impermanence uses
  # those to bind /var/lib/nixos and /var/log before activation, so those two
  # are declared as bind mounts here instead.
  #
  # NOTE: all of this is baked into boot.img. After changing anything in this
  # file or ./udev-retrigger.rb, reflash boot.img (README "Updating relic"),
  # and keep the layout of the flashed userdata in mind: it only changes by
  # reflashing userdata.

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=25%" "mode=755"]; # mode=755 so only root can write to those files
  };

  # The phone is carried around and its bootloader is unlocked, so anyone
  # holding it can `fastboot boot` their own image and read an unencrypted
  # userdata, including the ssh host key that decrypts every agenix secret.
  # Stage-1 asks for the passphrase on an on-screen keyboard. Of the NixOS
  # luks options it only honours `device`, `allowDiscards` and
  # `bypassWorkqueues`.
  boot.initrd.luks.devices.relic = {
    device = "/dev/disk/by-partlabel/userdata";
    # Flash storage benefits from TRIM being passed through to the disk.
    # Note: this leaks which blocks are in use; acceptable here.
    allowDiscards = true;
    # Skip dm-crypt's read/write workqueues so I/O is processed on the
    # submitting thread. Reduces latency and lifts throughput on fast
    # storage where the queues are the bottleneck.
    bypassWorkqueues = true;
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/relic";
    fsType = "ext4";
    neededForBoot = true;
    # system.img is only as big as the closure (plus a few percent), so the
    # filesystem is grown to fill userdata on boot. Stage-1's own `autoResize`
    # crashes on a /dev/dm-* device, so let systemd-growfs do it (online) in
    # stage-2 instead.
    autoResize = false;
    options = ["x-systemd.growfs"];
  };

  # Map the nested store to the standard /nix/store
  fileSystems."/nix/store" = {
    device = "/nix/nix/store";
    fsType = "none";
    options = ["bind"];
    neededForBoot = true;
  };

  # Map the nested var (the DB) to the standard /nix/var
  fileSystems."/nix/var" = {
    device = "/nix/nix/var";
    fsType = "none";
    options = ["bind"];
    neededForBoot = true;
  };

  # The uid and gid maps for entities without a static id is saved in
  # /var/lib/nixos. It must be in place before activation allocates ids.
  fileSystems."/var/lib/nixos" = {
    device = "/nix/persist/var/lib/nixos";
    fsType = "none";
    options = ["bind"];
    neededForBoot = true;
  };

  # Persist the journal from the very start of stage-2
  fileSystems."/var/log" = {
    device = "/nix/persist/var/log";
    fsType = "none";
    options = ["bind"];
    neededForBoot = true;
  };

  # Upstream enables growpart for "/", which is tmpfs here, so it would only
  # fail on every boot. /nix is grown by x-systemd.growfs above instead.
  boot.growPartition = false;

  # Work around a stage-1 hang (60 s, then a TASKS_HANG_TIMEOUT error screen)
  # where udev coldplug events are lost, so /dev/disk/by-partlabel never
  # appears. Seen in about a third of QEMU boots of this layout without LUKS.
  # With LUKS, lvm is in stage-1 and upstream already re-runs `udevadm
  # trigger` on every loop while /nix is pending (refresh_lvm in
  # boot/init/tasks/mount.rb), so this is only a fallback.
  # https://github.com/mobile-nixos/mobile-nixos/issues/461
  mobile.boot.stage-1.tasks = [./udev-retrigger.rb];

  swapDevices = [];
}

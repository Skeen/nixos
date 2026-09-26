{
  mobile-nixos,
  pkgs,
  ...
}: {
  # Mobile NixOS adds device support (kernel, firmware, boot image) for phones
  # to NixOS. It replaces the NixOS initrd with its own stage-1 (a Ruby
  # program in the initrd), and for Android devices builds two artifacts:
  #  - boot.img: kernel + device tree + stage-1 + kernel command line. Flashed
  #    to the `boot` partition(s) with fastboot.
  #  - system.img: an ext4 filesystem (label NIXOS_SYSTEM) holding the system
  #    closure. Flashed to the `userdata` partition once, at install time.
  # https://mobile.nixos.org
  # https://mobile.nixos.org/devices/oneplus-enchilada.html
  # https://github.com/mobile-nixos/mobile-nixos
  #
  # IMPORTANT: nixos-rebuild never touches boot.img (Mobile NixOS does not
  # implement a bootloader installer, hence the "do not know how to make this
  # configuration bootable" warning). Stage-1 boots the newest system
  # profile, so userland changes apply as usual and survive reboots, but
  # anything that lives in boot.img only applies after reflashing it:
  #  - the kernel. It is rebuilt on every nixpkgs bump (./kernel.nix), but
  #    its source only changes with Mobile NixOS bumps, so running the
  #    previously flashed build is fine.
  #  - boot.kernelParams (including mobile.beautification below)
  #  - mobile.boot.stage-1.* and boot.initrd.luks.*
  #  - fileSystems needed for boot (./hardware.nix)
  # https://github.com/mobile-nixos/mobile-nixos/issues/265

  imports = [
    # All Mobile NixOS modules, plus the OnePlus 6 device and its shared
    # sdm845-mainline family (kernel, firmware, audio, modem services, A/B).
    (import "${mobile-nixos}/lib/configuration.nix" {device = "oneplus-enchilada";})
  ];

  # system.img does not fit the ~3 GB `system` partition, so it is flashed to
  # `userdata` instead. This only affects the hint printed by
  # flash-critical.sh and the (unused) flashable zips, which would write the
  # unencrypted image over the LUKS container; the root filesystem is found by
  # ./hardware.nix, not by this option.
  mobile.system.android.system_partition_destination = "userdata";

  # Boot splash instead of scrolling kernel and systemd messages (as in the
  # Mobile NixOS phosh example). Both end up on the kernel command line.
  mobile.beautification = {
    silentBoot = true;
    splash = true;
  };

  # The device is A/B: the bootloader decrements a retry counter on each boot
  # and eventually marks the slot unbootable. boot-control (enabled by default
  # for SDM845) marks the booted slot successful once the system is up; check
  # it with `systemctl status boot-control`. qbootctl inspects and switches
  # slots by hand.
  environment.systemPackages = [pkgs.qbootctl];

  # Bring-up: when a boot fails, set silentBoot above to false, uncomment
  # the following, rebuild and reflash boot.img. This shows kernel output,
  # keeps the sad-phone error screen up instead of rebooting (after 10 s, or
  # 60 s for hung tasks and failed LUKS unlocks), and exposes stage-1 over USB
  # networking (phone 172.16.42.1, `ssh root@172.16.42.1`). Stage-1 ssh has a
  # blank root password, never leave it on. Crash logs (ramoops) of the
  # previous boot are archived to /var/lib/systemd/pstore once stage-2 runs;
  # in stage-1, `mount -t pstore pstore /sys/fs/pstore` first.
  # mobile.boot.stage-1.fail.reboot = false;
  # mobile.boot.stage-1.networking.enable = true;
  # mobile.boot.stage-1.ssh.enable = true;
}

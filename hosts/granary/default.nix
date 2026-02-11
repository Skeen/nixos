# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  secrets,
  nixpkgs-unstable,
  ...
}: {
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // {allowMissing = true;});
    })
    (final: super: {
      zfs = super.zfs.overrideAttrs (_: {
        meta.platforms = [];
      });
    })
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  imports = [
    (import "${nixpkgs-unstable}/nixos/modules/installer/sd-card/sd-image-aarch64.nix")
  ];

  nix.package = pkgs.nixVersions.stable;
  nix.nixPath = ["nixpkgs=${nixpkgs-unstable}"];
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems = pkgs.lib.mkForce ["btrfs" "cifs" "f2fs" "jfs" "ntfs" "reiserfs" "vfat" "xfs" "ext2"];
  boot.kernelParams = ["debug" "console=ttyS2,1500000"];
  boot.initrd.availableKernelModules = [
    "nvme"
    "nvme-core"
  ];
  hardware.deviceTree.enable = true;
  hardware.deviceTree.name = "rockchip/rk3566-odroid-m1s.dtb";
  system.stateVersion = "25.05";
  networking.hostName = "granary";

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  users.extraUsers.root.initialPassword = pkgs.lib.mkForce "odroid";
}

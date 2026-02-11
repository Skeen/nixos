# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  secrets,
  nixpkgs-unstable,
  uboot-src,
  ...
}: let
  uboot = pkgs.buildUBoot rec {
    extraMakeFlags = [
      "ROCKCHIP_TPL=${pkgs.rkbin}/bin/rk35/rk3566_ddr_1056MHz_v1.21.bin"
    ];
    extraMeta = {
      platforms = ["aarch64-linux"];
      license = pkgs.lib.licenses.unfreeRedistributableFirmware;
    };
    src = uboot-src;
    version = uboot-src.rev;
    defconfig = "odroid-m1s-rk3566_defconfig";
    filesToInstall = [
      "u-boot.bin"
      "u-boot-rockchip.bin"
      "idbloader.img"
      "u-boot.itb"
    ];
    BL31 = "${pkgs.rkbin}/bin/rk35/rk3568_bl31_v1.44.elf";
  };
in rec {
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
  sdImage = {
    compressImage = false;
    firmwareSize = 50;
    populateFirmwareCommands = ''
      cp ${uboot}/u-boot.bin firmware/
    '';
  };
  networking.hostName = "granary";

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  users.extraUsers.root.initialPassword = pkgs.lib.mkForce "odroid";
}

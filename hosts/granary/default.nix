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
  nixpkgs.hostPlatform = "aarch64-linux";

  imports = [
    ./hardware.nix
  ];

  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    git
  ];

  nix = {
    settings = {
      # Enable flakes
      experimental-features = ["nix-command" "flakes"];
    };
  };

  nix.package = pkgs.nixVersions.stable;
  nix.nixPath = ["nixpkgs=${nixpkgs-unstable}"];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems = pkgs.lib.mkForce ["btrfs" "cifs" "f2fs" "jfs" "ntfs" "reiserfs" "vfat" "xfs" "ext2"];
  boot.kernelParams = ["debug" "console=ttyS2,1500000"];

  system.stateVersion = "25.05";
  networking.hostName = "granary";

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  users.extraUsers.root.initialPassword = pkgs.lib.mkForce "odroid";
}

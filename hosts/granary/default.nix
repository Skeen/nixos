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
    ./agenix.nix
    ./hardware.nix
    ./impermanence.nix
    ./home-manager.nix
    ../../modules/base/git.nix
    ../../modules/server/ssh.nix
    ./wghub.nix
    ./jellyfin.nix
  ];

  environment.systemPackages = with pkgs; [
    vim 
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

  users.mutableUsers = false;
  users.users.root = {
    hashedPasswordFile = config.age.secrets.users-hashed-password-file.path;
  };

  users.users.emil = {
    isNormalUser = true;
    description = "Emil Madsen";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
      #  thunderbird
    ];
    hashedPasswordFile = config.age.secrets.users-hashed-password-file.path;
  };

  environment.persistence."/nix/persist" = {
    users.emil = {
      files = [
        "/.ssh/id_ed25519.pub"
        "/.ssh/id_ed25519"
      ];
    };
  };

  age.secrets.users-hashed-password-file = {
    file = "${secrets}/secrets/users-hashed-password-file.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

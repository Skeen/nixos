# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  secrets,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware.nix
    ./impermanence.nix
    ./home-manager.nix
    ./shell.nix
    ./agenix.nix
    ./ssh.nix
    ./ssh-key.nix
    ./ssh-known-hosts.nix
    ../../modules/base/git.nix
    ../../modules/base/nixos-containers.nix
    ./lunarvim.nix
    ./syncthing2.nix
    ./synapse.nix
    ./traggo.nix
    ./caddy.nix
    ./ipv6.nix
  ];

  nix = {
    settings = {
      # Enable flakes
      experimental-features = ["nix-command" "flakes"];
    };
  };

  # Bootloader
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  networking.hostName = "stronghold";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Set your time zone.
  time.timeZone = "Europe/Copenhagen";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_DK.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "da_DK.UTF-8";
    LC_IDENTIFICATION = "da_DK.UTF-8";
    LC_MEASUREMENT = "da_DK.UTF-8";
    LC_MONETARY = "da_DK.UTF-8";
    LC_NAME = "da_DK.UTF-8";
    LC_NUMERIC = "da_DK.UTF-8";
    LC_PAPER = "da_DK.UTF-8";
    LC_TELEPHONE = "da_DK.UTF-8";
    LC_TIME = "da_DK.UTF-8";
  };

  # Configure console keymap
  console.keyMap = "dk-latin1";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.mutableUsers = false;
  users.users.root = {
    # hashedPassword = "!"; # Disable root login
    hashedPasswordFile = config.age.secrets.users-hashed-password-file.path;
  };

  users.users.emil = {
    isNormalUser = true;
    description = "Emil Madsen";
    extraGroups = ["wheel"];
    packages = with pkgs; [
      #  thunderbird
    ];
    hashedPasswordFile = config.age.secrets.users-hashed-password-file.path;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    git
  ];

  # List services that you want to enable:

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home-manager.users.emil.home.stateVersion = "25.05"; # Did you read the comment?

  age.secrets.users-hashed-password-file = {
    file = "${secrets}/secrets/users-hashed-password-file.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

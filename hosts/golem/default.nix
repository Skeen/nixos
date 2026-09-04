# Golem: Hetzner Cloud server intended for AI workloads. This is the base
# system only (disk layout, impermanence, networking, users, secrets); the
# Kubernetes/Kata sandbox stack it is meant to carry is a separate concern and
# is not part of this configuration yet.
{
  config,
  pkgs,
  secrets,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware.nix
    ./disko.nix
    ./impermanence.nix
    ./home-manager.nix
    ./shell.nix
    ./agenix.nix
    ./ssh-key.nix
    ./network.nix
    ./housekeeping.nix
    ../../modules/server/ssh.nix
    ../../modules/base/git.nix
    ../../modules/base/fish.nix
  ];

  nix = {
    settings = {
      # Enable flakes
      experimental-features = ["nix-command" "flakes"];
    };
  };

  # Bootloader: see ./disko.nix. GRUB targets the same disk the layout
  # describes, so it is configured alongside it.

  networking.hostName = "golem";

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

  # Define a user account. Don't forget to set a password with `passwd`.
  users.mutableUsers = false;
  users.users.root = {
    hashedPasswordFile = config.age.secrets.users-hashed-password-file.path;
  };

  users.users.emil = {
    isNormalUser = true;
    description = "Emil Madsen";
    extraGroups = ["wheel"];
    hashedPasswordFile = config.age.secrets.users-hashed-password-file.path;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
  ];

  system.stateVersion = "25.05";

  # This value determines the Home Manager release that your
  # configuration is compatible with.
  home-manager.users.emil.home.stateVersion = "25.05"; # Did you read the comment?

  age.secrets.users-hashed-password-file = {
    file = "${secrets}/secrets/users-hashed-password-file.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

# Golem: Hetzner Cloud server for AI workloads. Similar to stronghold, but
# instead of hosting web services it runs a single-node Kubernetes cluster
# whose workloads (AI agent sandboxes) are isolated in Kata Containers
# MicroVMs behind the kubernetes-sigs/agent-sandbox CRDs.
{
  config,
  pkgs,
  secrets,
  ...
}: {
  imports = [
    ./hardware.nix
    ./impermanence.nix
    ./home-manager.nix
    ./shell.nix
    ./agenix.nix
    ./network.nix
    ./kubectl.nix
    ./kubernetes.nix
    ./agent-sandbox.nix
    ./sandbox.nix
    ../../modules/server/ssh.nix
    ../../modules/base/git.nix
    ../../modules/base/fish.nix
    ./housekeeping.nix
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
    packages = with pkgs; [
      #  thunderbird
    ];
    hashedPasswordFile = config.age.secrets.users-hashed-password-file.path;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System tooling for running the cluster
  environment.systemPackages = with pkgs; [
    git
    kubectl
    kubernetes-helm
    cri-tools # crictl, for poking at containerd directly
  ];

  # /dev/kvm for Kata's QEMU MicroVMs. Hetzner CCX instances expose nested
  # virtualization; containerd runs as root, so its shims can use /dev/kvm.
  boot.kernelModules = ["kvm-intel"];
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

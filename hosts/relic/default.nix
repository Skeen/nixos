# relic: OnePlus 6 phone (Mobile NixOS device "oneplus-enchilada") running
# the Phosh shell.
#
# relic differs from the other hosts in two ways:
#  - It is built from `nixpkgs-unstable` (see flake.nix). Mobile NixOS tracks
#    nixos-unstable and no longer evaluates against 25.05.
#  - NixOS does not manage its bootloader. The kernel and the Mobile NixOS
#    stage-1 (initrd) live in an Android boot.img that is flashed with
#    fastboot, while `nixos-rebuild switch` only moves the system profile that
#    stage-1 boots. See ./mobile-nixos.nix and the README section
#    "Installing relic".
{
  config,
  pkgs,
  secrets,
  ...
}: {
  nixpkgs.hostPlatform = "aarch64-linux";

  imports = [
    ./mobile-nixos.nix
    ./kernel.nix
    ./firmware.nix
    ./hardware.nix
    ./rootfs.nix
    ./impermanence.nix
    ./agenix.nix
    ./home-manager.nix
    ./network.nix
    ./phosh/default.nix
    ../../modules/base/fish.nix
    ../../modules/base/git.nix
    ../../modules/server/ssh.nix
  ];

  nix = {
    settings = {
      # Enable flakes
      experimental-features = ["nix-command" "flakes"];
      # Allow wheel users (emil) to push unsigned store paths, so relic can be
      # deployed remotely from hearth via `nixos-rebuild --target-host`.
      trusted-users = ["@wheel"];
    };
  };

  # Allow unfree packages. The OnePlus 6 firmware blobs (modem, wifi, GPU,
  # DSPs) that Mobile NixOS packages as `oneplus-sdm845-firmware` are unfree.
  nixpkgs.config.allowUnfree = true;

  # Mobile NixOS turns off the split (cacheable) options build, so the NixOS
  # manual is never in the binary cache and would be rebuilt under qemu after
  # every nixpkgs or Mobile NixOS bump.
  documentation.nixos.enable = false;

  networking.hostName = "relic";

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

  # Keymap for hardware (USB/Bluetooth) keyboards. gnome-settings-daemon also
  # seeds the Phosh input sources from this on first login; the on-screen
  # keyboard layout itself is set in ./phosh/keyboard.nix.
  services.xserver.xkb = {
    layout = "dk";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "dk-latin1";

  users.mutableUsers = false;
  users.users.root = {
    hashedPasswordFile = config.age.secrets.users-hashed-password-file.path;
  };

  users.users.emil = {
    isNormalUser = true;
    description = "Emil Madsen";
    extraGroups = ["networkmanager" "wheel"];
    hashedPasswordFile = config.age.secrets.users-hashed-password-file.path;
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    tree
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  # relic is first installed from nixpkgs-unstable (26.11pre), not 25.05.
  system.stateVersion = "26.11"; # Did you read the comment?

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home-manager.users.emil.home.stateVersion = "26.11"; # Did you read the comment?

  age.secrets.users-hashed-password-file = {
    file = "${secrets}/secrets/users-hashed-password-file.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

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
    ./disko.nix
    ./impermanence.nix
    ./jovian.nix
    ./housekeeping.nix
    ../../modules/base/fish.nix
    ./home-manager.nix
    ./agenix.nix
    ../../modules/base/git.nix
    ../../modules/server/ssh.nix
  ];

  nix = {
    settings = {
      # Enable flakes
      experimental-features = ["nix-command" "flakes"];
      # Allow wheel users (emil) to push unsigned store paths, so jester can
      # be deployed remotely from another host via `nixos-rebuild --target-host`.
      trusted-users = ["@wheel"];
    };
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  # Every Jovian kernel bump lands a new kernel and a firmware-heavy initrd on
  # the ESP, so cap the number of generations kept there.
  boot.loader.systemd-boot.configurationLimit = 10;
  # Steam Deck BIOS updates are known to wipe the NVRAM boot entries. bootctl
  # also installs the removable-media fallback (EFI/BOOT/BOOTX64.EFI), which
  # the firmware boots when no entry is left.
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "jester"; # Define your hostname.

  # Enable networking
  # Steam's first-time setup and Wi-Fi settings talk to NetworkManager.
  networking.networkmanager.enable = true;
  networking.networkmanager.ensureProfiles.environmentFiles = [
    config.age.secrets.home-wifi-password-file.path
  ];
  networking.networkmanager.ensureProfiles.profiles = {
    "home-wifi" = {
      connection = {
        id = "FRITZ!Box 6670 FM";
        uuid = "4fece54c-fc57-428f-afbc-5b6003d9723e";
        type = "wifi";
        # No interface-name: the Wi-Fi chip differs between the LCD (Realtek)
        # and OLED (Qualcomm) models, and steamos-manager may rename it.
        autoconnect = true;
      };

      wifi = {
        mode = "infrastructure";
        ssid = "FRITZ!Box 6670 FM";
      };

      "wifi-security" = {
        key-mgmt = "wpa-psk";
        auth-alg = "open";
        psk = "$HOME_WIFI_PSK";
      };

      ipv4 = {
        method = "auto";
      };

      ipv6 = {
        addr-gen-mode = "default";
        method = "auto";
      };
    };
  };

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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the XFCE Desktop Environment, used by "Switch to Desktop" (see
  # ./jovian.nix). Jovian owns the display manager (SDDM, autologin into
  # Gaming Mode), so unlike the other hosts there is no lightdm or autoLogin.
  services.xserver.desktopManager.xfce = {
    enable = true;
    # The lock screen wants a typed password, and the Deck has no keyboard.
    enableScreensaver = false;
  };

  # Jovian sets logind HandlePowerKey=ignore in favour of its powerbuttond,
  # which only runs in Gaming Mode. In the desktop session the button is left
  # to xfce4-power-manager, which does nothing with it by default.
  home-manager.users.emil.xfconf.settings.xfce4-power-manager = {
    # Power Manager: General: When power button is pressed: Ask
    "xfce4-power-manager/power-button-action" = 3;
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "dk";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "dk-latin1";

  # Sound (pipewire with the Deck's DSP configuration) is set up by Jovian.
  security.rtkit.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.mutableUsers = false;
  users.users.root = {
    hashedPasswordFile = config.age.secrets.users-hashed-password-file.path;
  };

  users.users.emil = {
    # Jovian's microSD automount script hardcodes the Steam user as uid 1000.
    uid = 1000;
    isNormalUser = true;
    description = "Emil Madsen";
    extraGroups = ["networkmanager" "wheel"];
    hashedPasswordFile = config.age.secrets.users-hashed-password-file.path;
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  # jester is installed from nixpkgs-unstable (26.11pre), see flake.nix.
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

  age.secrets.home-wifi-password-file = {
    file = "${secrets}/secrets/home-wifi-password-file.env.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

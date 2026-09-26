{
  config,
  secrets,
  ...
}: {
  # NetworkManager handles Wi-Fi and, through ModemManager (enabled by
  # default alongside NetworkManager), the cellular modem. Phosh's Wi-Fi and
  # mobile data toggles talk to it.
  networking.networkmanager.enable = true;

  # Mobile data needs an APN: add it once in Settings > Mobile Network. It is
  # persisted with the other connections (./impermanence.nix).
  # NOTE: mobile data is reported broken on the Mobile NixOS 6.4 kernel (it
  # lacks CONFIG_RMNET), while SMS works. Calls connect but have no audio:
  # nothing runs q6voiced, and the UCM Mobile NixOS pins has no "Voice Call"
  # verb for the OnePlus 6.
  # https://github.com/mobile-nixos/mobile-nixos/issues/830

  # Home wifi, same profile as satchel, minus `interface-name`: the phone has
  # a single Wi-Fi device (ath10k, most likely wlan0), and without the key
  # NetworkManager uses the profile on any Wi-Fi device.
  networking.networkmanager.ensureProfiles.environmentFiles = [
    config.age.secrets.home-wifi-password-file.path
  ];
  networking.networkmanager.ensureProfiles.profiles = {
    "home-wifi" = {
      connection = {
        id = "FRITZ!Box 6670 FM";
        uuid = "4fece54c-fc57-428f-afbc-5b6003d9723e";
        type = "wifi";
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

  age.secrets.home-wifi-password-file = {
    file = "${secrets}/secrets/home-wifi-password-file.env.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

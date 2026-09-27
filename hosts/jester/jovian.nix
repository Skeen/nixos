{jovian, ...}: {
  # Jovian NixOS brings SteamOS's Gaming Mode and the Steam Deck hardware
  # support (kernel, firmware, fan control, audio DSP, controller and display
  # quirks) to NixOS.
  # https://jovian-experiments.github.io/Jovian-NixOS/
  # https://github.com/Jovian-Experiments/Jovian-NixOS

  imports = [
    jovian.nixosModules.default
  ];

  jovian.devices.steamdeck.enable = true;

  jovian.steam = {
    enable = true;
    # Boot straight into Gaming Mode. Jovian sets up SDDM with autologin into
    # the gamescope session for this, so no other display manager may be set.
    autoStart = true;
    user = "emil";
    # Session opened by "Switch to Desktop" in the power menu. Logging out of
    # it returns to Gaming Mode.
    desktopSession = "xfce";
  };
}

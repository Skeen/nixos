{ ... }: {
  # On-screen keyboard for the desktop session, as the Deck has no keyboard.
  # Gaming Mode uses Steam's own keyboard instead.
  # https://launchpad.net/onboard
  home-manager.users.emil = { pkgs, ... }: {
    home.packages = [pkgs.onboard];

    # onboard's own autostart entry only runs in GNOME, Unity and MATE
    xdg.autostart = {
      enable = true;
      entries = ["${pkgs.onboard}/share/applications/onboard.desktop"];
    };

    dconf.settings = {
      "org/onboard" = {
        # Start hidden, with its icon in the panel's notification area to show
        # or hide it by hand
        start-minimized = true;
        show-status-icon = true;
      };
      # Pop up whenever a text field gets focus. This relies on the AT-SPI
      # accessibility bus, which the xfce module enables.
      "org/onboard/auto-show".enabled = true;
      # Dock along the bottom edge and shrink the usable screen area, so
      # maximized windows are not hidden behind the keyboard
      "org/onboard/window" = {
        docking-enabled = true;
        docking-edge = "bottom";
        docking-shrink-workarea = true;
      };
    };
  };
}

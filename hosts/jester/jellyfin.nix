{...}: {
  # Jellyfin client for the media server on granary, served at
  # https://jellyfin.awful.engineer. To use it from Gaming Mode, add it to
  # Steam as a non-Steam game from the desktop session.
  # https://github.com/jellyfin/jellyfin-desktop
  home-manager.users.emil = {pkgs, ...}: {
    home.packages = [
      # SDL's Steam Deck driver turns off the controller's lizard mode (its
      # trackpad mouse emulation) while the controller is open, and Jellyfin
      # keeps it open for as long as it runs, so the desktop loses its mouse.
      # Without the driver SDL falls back to its generic Linux one.
      #
      # Also start fullscreen, as a window wastes most of the Deck's small
      # screen. To leave it, map Alt+F4 or F11 to a button in Steam's Desktop
      # Layout, see ./controller.nix.
      (pkgs.symlinkJoin {
        name = "jellyfin-desktop-wrapped";
        paths = [pkgs.jellyfin-desktop];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/jellyfin-desktop \
            --set SDL_JOYSTICK_HIDAPI_STEAMDECK 0 \
            --add-flags --fullscreen
        '';
      })
    ];
  };
}

{ pkgs, ... }: {
  # 1. Ensure the font is installed
  #
  # The font is installed system-wide instead of via home.packages, as NixOS
  # pre-builds the fontconfig cache for fonts.packages. Fonts in the user
  # profile defeat fontconfig's mtime-based cache invalidation (nix store
  # mtimes are fixed at the epoch), requiring a manual `fc-cache -f` after
  # every change.
  fonts.packages = with pkgs; [
    nerd-fonts.hack
  ];

  home-manager.users.emil = { pkgs, lib, ... }: {
    # 2. Purge the XFCE database
    #
    # We install a hook to purge all entries in the xfce4-terminal database.
    # This ensures that only the defined configuration below is in effect.
    # I.e. it protects us from whatever defaults the xfce developers left us.
    #
    # The hook is installed in the 'checkLinkTargets' phase of home-manager,
    # this is a very early phase ensuring that home-manager has not yet written
    # the configuration file below, nor has started the xfce4-terminal.
    home.activation.wipeXfceTerminal = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      echo "Purging Xfce4 Terminal config to ensure only the defined config runs..."
      # Removes all entries for xfce4-terminal in '/' and below (recursive)
      ${pkgs.xfce.xfconf}/bin/xfconf-query --channel xfce4-terminal --property / --reset --recursive || true
    '';

    # 3. Configure the terminal
    xfconf.settings = {
      xfce4-terminal = {
        # We want the terminal to use the installed font to show special glyphs
        # Appearance: Font: Use system font
        "font-use-system" = false;
        # Appearance: Font: Picker
        "font-name" = "Hack Nerd Font Mono 12";

        # Cursor should be a blinking block
        # General: Cursor: Cursor shape
        "misc-cursor-shape" = "TERMINAL_CURSOR_SHAPE_BLOCK";
        # General: Cursor: Cursor blinks
        "misc-cursor-blinks" = true;

        # We want unlimited scrollback
        # General: Scrolling: Unlimited Scrollback
        "scrolling-unlimited" = true;

        # Do not show the annoying paste warning -> I know what I am doing (mostly)
        # General: Clipboard: Show unsafe paste dialog
        "misc-show-unsafe-paste-dialog" = false;

        # Start terminal windows as maximized
        # Appearance: Opening New Windows: Maximize new windows
        "misc-maximize-default" = true;
      };
    };
  };
}

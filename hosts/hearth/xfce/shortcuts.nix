{ ... }: {
  home-manager.users.emil = { pkgs, lib, ... }: {

    # 1. Ensure the needed programs are available
    home.packages = with pkgs; [
      # wpctl
      wireplumber
      # xkill
      xorg.xkill
      # xfce4 tools
      xfce.xfce4-panel  # xfce4-popup-applicationsmenu
      xfce.xfce4-session  # xfce4-session-logout, xflock4
      xfce.xfce4-taskmanager
      xfce.xfce4-screenshooter
      xfce.xfce4-appfinder
      xfce.exo  # exo-open
    ];

    # 2. Purge the XFCE database
    #
    # We install a hook to purge all entries in the xfce4-keyboard-shortcuts database.
    # This ensures that only the defined configuration below is in effect.
    # I.e. it protects us from whatever defaults the xfce developers left us.
    #
    # The hook is installed in the 'checkLinkTargets' phase of home-manager,
    # this is a very early phase ensuring that home-manager has not yet written
    # the configuration file below, nor has started the xfce4-keyboard-shortcuts.
    home.activation.wipeXfceShorcuts = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      echo "Purging Xfce4 Keyboard Shortcuts config to ensure only the defined config runs..."
      # Removes all entries for xfce4-keyboard-shortcuts in '/' and below (recursive)
      ${pkgs.xfce.xfconf}/bin/xfconf-query --channel xfce4-keyboard-shortcuts --property / --reset --recursive || true
    '';

    # 3. Configure the panel
    xfconf.settings = {
      xfce4-keyboard-shortcuts = {
        # Register both commands and xfwm4 (window manager shortcuts from the below)
        "providers" = "[xfwm4,commands]";

        # Interpret 'custom' commands as overrides for defaults
        "commands/custom/override" = true;
        "xfwm4/custom/override" = true;

        # Audio controls
        # This uses the wpctl util directly as the xfce4-panel pulseaudio plugin's
        # keyboard control leaves much to be desired
        "commands/custom/AudioLowerVolume" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-";
        "commands/custom/AudioRaiseVolume" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+";
        "commands/custom/AudioMute" = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";

        # Program launchers
        "commands/custom/<Alt>F1" = "xfce4-popup-applicationsmenu";
        "commands/custom/<Alt>F2" = "xfce4-appfinder --collapsed";
        "commands/custom/<Alt>F2/startup-notify" = "true";
        "commands/custom/<Alt>F3" = "xfce4-appfinder";
        "commands/custom/<Alt>F3/startup-notify" = "true";

        # Screenshot
        "commands/custom/Print" = "xfce4-screenshooter";
        "commands/custom/<Alt>Print" = "xfce4-screenshooter -w";
        "commands/custom/<Shift>Print" = "xfce4-screenshooter -r";

        # Control alt q to logout
        "commands/custom/<Control><Alt>q" = "xfce4-session-logout";
        # Control alt escape to xkill
        "commands/custom/<Control><Alt>Escape" = "xkill";
        # Control alt l to lock
        "commands/custom/Sleep" = "xflock4";
        "commands/custom/<Control><Alt>l" = "xflock4";
        # Control alt t for terminal
        "commands/custom/<Control><Alt>t" = "exo-open --launch TerminalEmulator";
        # Control alt delete for task manager
        "commands/custom/<Control><Alt>Delete" = "xfce4-taskmanager";

        # Maximize the current window
        "xfwm4/custom/<Alt>F10" = "maximize_window_key";
        # Full screen the current window
        "xfwm4/custom/<Alt>F11" = "fullscreen_key";
        # Configure the current window to be "Always on Top"
        "xfwm4/custom/<Alt>F12" = "above_key";
        # Close the current window
        "xfwm4/custom/<Alt>F4" = "close_window_key";
        # ???
        "xfwm4/custom/<Alt>F6" = "stick_window_key";
        # Move the current window
        "xfwm4/custom/<Alt>F7" = "move_window_key";
        # Resize the current window
        "xfwm4/custom/<Alt>F8" = "resize_window_key";
        # Hide the current window
        "xfwm4/custom/<Alt>F9" = "hide_window_key";

        # Cycle through windows forwards and backwards
        "xfwm4/custom/<Alt>Tab" = "cycle_windows_key";
        "xfwm4/custom/<Alt><Shift>Tab" = "cycle_reverse_windows_key";
        # Cycle through windows without picker
        "xfwm4/custom/<Super>Tab" = "switch_window_key";

        # Open the window menu
        "xfwm4/custom/<Alt>space" = "popup_menu_key";

        "xfwm4/custom/Escape" = "cancel_key";

        # Minimize all windows showing the desktop
        "xfwm4/custom/<Control><Alt>d" = "show_desktop_key";
        # Go right or left in workspaces
        "xfwm4/custom/<Control><Alt>Left" = "left_workspace_key";
        "xfwm4/custom/<Control><Alt>Right" = "right_workspace_key";
        # Move the current window to the next or previous workspace
        "xfwm4/custom/<Control><Alt>End" = "move_window_next_workspace_key";
        "xfwm4/custom/<Control><Alt>Home" = "move_window_prev_workspace_key";

        # Go to workspace n
        "xfwm4/custom/<Control>F1" = "workspace_1_key";
        "xfwm4/custom/<Control>F2" = "workspace_2_key";
        "xfwm4/custom/<Control>F3" = "workspace_3_key";
        "xfwm4/custom/<Control>F4" = "workspace_4_key";
        "xfwm4/custom/<Control>F5" = "workspace_5_key";
        "xfwm4/custom/<Control>F6" = "workspace_6_key";
        "xfwm4/custom/<Control>F7" = "workspace_7_key";
        "xfwm4/custom/<Control>F8" = "workspace_8_key";
        "xfwm4/custom/<Control>F9" = "workspace_9_key";
        "xfwm4/custom/<Control>F10" = "workspace_10_key";
        "xfwm4/custom/<Control>F11" = "workspace_11_key";
        "xfwm4/custom/<Control>F12" = "workspace_12_key";

        # Control window tiling
        "xfwm4/custom/<Super>KP_Down" = "tile_down_key";
        "xfwm4/custom/<Super>KP_End" = "tile_down_left_key";
        "xfwm4/custom/<Super>KP_Home" = "tile_up_left_key";
        "xfwm4/custom/<Super>KP_Left" = "tile_left_key";
        "xfwm4/custom/<Super>KP_Next" = "tile_down_right_key";
        "xfwm4/custom/<Super>KP_Page_Up" = "tile_up_right_key";
        "xfwm4/custom/<Super>KP_Right" = "tile_right_key";
        "xfwm4/custom/<Super>KP_Up" = "tile_up_key";
      };
    };
  };
}


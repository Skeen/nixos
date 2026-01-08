{ ... }: {
  home-manager.users.emil = { pkgs, lib, ... }: {
    # 1. Purge the XFCE database
    #
    # We install a hook to purge all entries in the xfce4-screensaver database.
    # This ensures that only the defined configuration below is in effect.
    # I.e. it protects us from whatever defaults the xfce developers left us.
    #
    # The hook is installed in the 'checkLinkTargets' phase of home-manager,
    # this is a very early phase ensuring that home-manager has not yet written
    # the configuration file below, nor has started the xfce4-screensaver.
    home.activation.wipeXfceScreensaver = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      echo "Purging Xfce4 Screensaver config to ensure only the defined config runs..."
      # Removes all entries for xfce4-screensaver in '/' and below (recursive)
      ${pkgs.xfce.xfconf}/bin/xfconf-query --channel xfce4-screensaver --property / --reset --recursive || true
    '';

    # 2. Configure the screensaver
    xfconf.settings = {
      xfce4-screensaver = {
        # Enable lock screen such that <Control><Alt>L and similar work
        # Lock Screen: Enable Lock Screen
        "lock/enabled" = true;

        # Disable switching users from the lock screen
        # Lock Screen: User Switching
        "lock/user-switching/enabled" = false;

        # Disable logging out from the lock screen
        # Lock Screen: Logout
        "lock/logout/enabled" = false;

        # Enable the lock screen when returning from sleep / suspend
        # Lock Screen: Lock Screen with System Sleep
        "lock/sleep-activation" = true;

        # Lock the screen when the screensaver becomes enabled
        "lock/saver-activation/enabled" = true;

        # Do not enable the screensaver automatically at idle, wait for manual instruction to do so
        # Screensaver: Activate screensaver when computer is idle
        "saver/idle-activation/enabled" = false;

        # When screensaver is enable simply show a blank screen
        # Screensaver: Theme
        # 0 = Blank screen
        # 1 = Random screensaver
        # 2 = Specific screensaver
        # Both 1 and 2 select the screensaver from `saver/themes/list`
        "saver/mode" = 2;

        # Use the "Floating Xfce" logos screensaver
        # Screensaver: Theme
        "saver/themes/list" = ["screensavers-xfce-floaters"];
      };
      xfce4-power-manager = {
        # Allow the lock screen to actually turn off the monitor
        # Display: Display power management
        "dpms-enabled" = true;
        # Do not go to turn off the monitor automatically, wait for manual instruction to do so
        # Display: Put to sleep after
        "dpms-on-ac-sleep" = 0;
        # Do not go to turn off the monitor automatically, wait for manual instruction to do so
        # Display: Switch off after
        "dpms-on-ac-off" = 0;

        # Enable power management notifications, this is mostly useless on desktop, but useful on battery powered devices
        # General: Appearance: Status notifications
        "general-notification" = true;

        # Do not show the power management tray icon
        # If we wanted power management on the panel we would use the xfce4-panel power management plugin
        # General: Appearance: System tray icon
        "show-tray-icon" = false;

        # Power button configuration
        #
        # Configure each button for their intended purpose, i.e.
        # Sleep button for sleep / suspend
        # Hibernate button for hibernate
        # Power button for power-off / shutdown
        # Battery button to ask what its purpose is
        #
        # Enum:
        # 0 = Do nothing
        # 1 = Sleep / Suspend
        # 2 = Hibernate
        # 3 = Ask
        # 4 = Shutdown
        # 5 = Hybrid Sleep
        #
        # General: Buttons: When * button is pressed
        "sleep-button-action" = 1;
        "hibernate-button-action" = 2;
        "battery-button-action" = 3;
        "power-button-action" = 4;

        # Lock the screen on suspend or hibernation
        # System: Security: Lock screen when system is going to sleep
        "lock-screen-suspend-hibernate" = true;
        # Configure the system to sleep in Sleep / Suspend mode
        # Note: This uses the same enum as the power button configuration
        # System: System power saving: System sleep mode
        "inactivity-sleep-mode-on-ac" = 1;
        # Do not go to sleep automatically, wait for manual instruction to do so
        # System: System power saving: When inactive for
        "inactivity-on-ac" = 0;
      };
    };
  };
}

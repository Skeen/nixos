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

    # As above, but for xfce4-power-manager. This also clears any orphaned keys
    # written to the channel root instead of under the /xfce4-power-manager/
    # prefix that the daemon actually reads.
    home.activation.wipeXfcePowerManager = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      echo "Purging Xfce4 Power Manager config to ensure only the defined config runs..."
      ${pkgs.xfce.xfconf}/bin/xfconf-query --channel xfce4-power-manager --property / --reset --recursive || true
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
        # NOTE: xfce4-power-manager stores every setting under a
        # /xfce4-power-manager/ property prefix within its own channel. Keys
        # written to the channel root are silently ignored by the daemon, so
        # every property below must carry the "xfce4-power-manager/" prefix.

        # Allow the lock screen to actually turn off the monitor
        # Display: Display power management
        "xfce4-power-manager/dpms-enabled" = true;
        # Do not go to turn off the monitor automatically, wait for manual instruction to do so
        # Display: Put to sleep after
        "xfce4-power-manager/dpms-on-ac-sleep" = 0;
        # Do not go to turn off the monitor automatically, wait for manual instruction to do so
        # Display: Switch off after
        "xfce4-power-manager/dpms-on-ac-off" = 0;
        # Same on battery: the screen should never blank automatically
        "xfce4-power-manager/dpms-on-battery-sleep" = 0;
        "xfce4-power-manager/dpms-on-battery-off" = 0;
        # Disable the plain X server screen blanking (non-DPMS) on both AC and battery
        "xfce4-power-manager/blank-on-ac" = 0;
        "xfce4-power-manager/blank-on-battery" = 0;

        # Enable power management notifications, this is mostly useless on desktop, but useful on battery powered devices
        # General: Appearance: Status notifications
        "xfce4-power-manager/general-notification" = true;

        # Show the power management tray icon so the battery status is visible
        # General: Appearance: System tray icon
        "xfce4-power-manager/show-tray-icon" = true;

        # Power/sleep/hibernate/battery button configuration.
        #
        # Button action enum:
        # 0 = Do nothing
        # 1 = Sleep / Suspend
        # 2 = Hibernate
        # 3 = Ask
        # 4 = Shutdown
        # 5 = Hybrid Sleep
        #
        # General: Buttons: When * button is pressed
        "xfce4-power-manager/sleep-button-action" = 1;
        "xfce4-power-manager/hibernate-button-action" = 2;
        "xfce4-power-manager/battery-button-action" = 3;
        "xfce4-power-manager/power-button-action" = 3;

        # Lock the screen on suspend or hibernation
        # System: Security: Lock screen when system is going to sleep
        "xfce4-power-manager/lock-screen-suspend-hibernate" = true;
        # Configure the system to sleep in Sleep / Suspend mode
        # Note: This uses the same enum as the power button configuration
        # System: System power saving: System sleep mode
        "xfce4-power-manager/inactivity-sleep-mode-on-ac" = 1;
        "xfce4-power-manager/inactivity-sleep-mode-on-battery" = 1;
        # Do not go to sleep automatically, wait for manual instruction to do so
        # This applies on both AC and battery: never auto-sleep or switch off
        # System: System power saving: When inactive for
        "xfce4-power-manager/inactivity-on-ac" = 0;
        "xfce4-power-manager/inactivity-on-battery" = 0;

        # The lid is a hinge, not a command: do nothing on close, on both AC and
        # battery. xfce4-power-manager owns the lid, not logind.
        #
        # Lid action enum (distinct from the button enum above):
        # 0 = Do nothing
        # 1 = Switch off display
        # 2 = Lock screen
        # 3 = Suspend
        # 4 = Hibernate
        # 5 = Hybrid Sleep
        # 6 = Shutdown
        "xfce4-power-manager/logind-handle-lid-switch" = false;
        "xfce4-power-manager/lid-action-on-ac" = 0;
        "xfce4-power-manager/lid-action-on-battery" = 0;
      };
    };
  };
}

# NOTE: It may be necessary to run: `xfce4-desktop --reload` after `nixos-rebuild switch`.
#       This is the case as xfce4-desktop may otherwise cache the old configuration.

{ ... }:
let
  # NOTE: This should be aligned with monitors.nix
  monitors = ["DP-3" "HDMI-1" "HDMI-2" "HDMI-3"];

  generate-monitor-settings = monitor: {
    # Desktop Settings: Background: Style: None (Solid Color) (instead of image)
    "backdrop/screen0/monitor${monitor}/workspace0/image-style" = 0;
    # Desktop Settings: Background: Color: Solid Color (instead of Gradient et al.)
    "backdrop/screen0/monitor${monitor}/workspace0/color-style" = 0;
    # Desktop Settings: Background: Color: Color Picker (Black)
    "backdrop/screen0/monitor${monitor}/workspace0/rgba1" = [0.0 0.0 0.0 1.0];
  };

  global-settings = {
    # Desktop Settings: Background: Apply to all workspaces
    # i.e. use same bg configuration for all workspaces
    "backdrop/single-workspace-mode" = true;
    # Use workspace 0 as the source for all workspaces
    "backdrop/single-workspace-number" = 0;
  };

in
{
  home-manager.users.emil = { pkgs, lib, ... }: {

    # 1. Ensure xfce4-desktop is available
    home.packages = with pkgs.xfce; [
      xfdesktop
    ];

    # 2. Purge the XFCE database
    #
    # We install a hook to purge all entries in the xfce4-desktop database.
    # This ensures that only the defined configuration below is in effect.
    # I.e. it protects us from whatever defaults the xfce developers left us.
    #
    # The hook is installed in the 'checkLinkTargets' phase of home-manager,
    # this is a very early phase ensuring that home-manager has not yet written
    # the configuration file below, nor has started the xfce4-panel.
    home.activation.wipeXfceDesktop = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      echo "Purging Xfce4 Desktop config to ensure only the defined config runs..."
      # Removes all entries for xfce4-desktop in '/' and below (recursive)
      ${pkgs.xfce.xfconf}/bin/xfconf-query --channel xfce4-desktop --property / --reset --recursive || true
    '';

    # 3. Configure the panel
    xfconf.settings = {
      xfce4-desktop = lib.mkMerge (
        (map generate-monitor-settings monitors) ++ [ global-settings ]
      );
    };
  };
}

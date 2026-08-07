# NOTE: It may be necessary to run: `xfce4-panel --restart` after `nixos-rebuild switch`.
#       This is the case as xfce4-panel may otherwise cache the old configuration.

{ lib, ... }:
let
  # Define a reusable helper
  enumerate = list: lib.listToAttrs (lib.imap1 (i: n: { name = n; value = i; }) list);
  # Plugin IDs must be defined here, inside this file
  pluginIds = enumerate [
    "menu"
    "tasklist"
    "separator1"
    "workspaces"
    "separator2"
    "systray"
    "separator3"
    "audio"
    "separator4"
    "voxtype"
    "separator5"
    "clock"
    "separator6"
    "power"
  ];
in
{
  home-manager.users.emil = { config, pkgs, lib, ... }: let

    # Clicking the indicator stops or starts the voxtype service, so the
    # microphone can be shut off entirely.
    voxtypeToggle = pkgs.writeShellScript "genmon-voxtype-toggle" ''
      if ${pkgs.systemd}/bin/systemctl --user is-active --quiet voxtype; then
        ${pkgs.systemd}/bin/systemctl --user stop voxtype
      else
        ${pkgs.systemd}/bin/systemctl --user start voxtype
      fi
    '';

    # Voice-to-text indicator, see ../voxtype.nix
    voxtypeIndicator = pkgs.writeShellScript "genmon-voxtype" ''
      case "$(${config.services.voxtype.package}/bin/voxtype status)" in
        recording | streaming) colour="#e01b24"; dot="●"; tip="Voxtype: recording" ;;
        transcribing)          colour="#e5a50a"; dot="●"; tip="Voxtype: transcribing" ;;
        idle)                  colour="#2ec27e"; dot="●"; tip="Voxtype: loaded, click to unload" ;;
        stopped)               colour="#77767b"; dot="○"; tip="Voxtype: unloaded, click to load" ;;
        *)                     colour="#c061cb"; dot="?"; tip="Voxtype: unknown state" ;;
      esac
      echo "<txt><span foreground='$colour'>$dot</span></txt><tool>$tip</tool><txtclick>${voxtypeToggle}</txtclick>"
    '';

  in {

    # 1. Ensure xfce4-panel and needed plugins are available
    home.packages = with pkgs.xfce; [
      xfce4-panel
      xfce4-pulseaudio-plugin
      xfce4-genmon-plugin
    ];

    # 2. Purge the XFCE database
    #
    # We install a hook to purge all entries in the xfce4-panel database.
    # This ensures that only the defined configuration below is in effect.
    # I.e. it protects us from whatever defaults the xfce developers left us.
    #
    # The hook is installed in the 'checkLinkTargets' phase of home-manager,
    # this is a very early phase ensuring that home-manager has not yet written
    # the configuration file below, nor has started the xfce4-panel.
    home.activation.wipeXfcePanel = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      echo "Purging Xfce4 Panel config to ensure only the defined config runs..."
      # Removes all entries for xfce4-panel in '/' and below (recursive)
      ${pkgs.xfce.xfconf}/bin/xfconf-query --channel xfce4-panel --property / --reset --recursive || true
    '';

    # 3. Configure the panel
    xfconf.settings = {
      xfce4-panel = {
        # We only want a single panel
        "panels" = [ 1 ];

        # Output the panel on the primary monitor
        # Panel Preferences: Display: Output: Primary
        "panels/panel-1/output-name" = "Primary";

        # Ensure the panel is locked to disincentivize manual changes
        # Panel Preferences: Display: General: Lock panel
        "panels/panel-1/position-locked" = true;

        # Ensure the panel is snapped to the top of the screen (6=top left)
        "panels/panel-1/position" = "p=6;x=0;y=0";

        # Limit icon size so the bar remains slim at the top of the screen
        # Panel Preferences: Appearance: Icons: Fixed icon size (pixels)
        "panels/panel-1/icon-size" = 16;

        # Enable darkmode for the panels
        # Panel Preferences: Appearance: General: Dark mode
        "panels/dark-mode" = true;

        # Panel Preferences: Display: Measurements: Row size (pixels)
        "panels/panel-1/size" = 26;
        # Panel Preferences: Display: Measurements: Length (pixels)
        "panels/panel-1/length" = 100;

        # Panel Preferences: Items
        "panels/panel-1/plugin-ids" = [
          pluginIds.menu
          pluginIds.tasklist
          pluginIds.separator1
          pluginIds.workspaces
          pluginIds.separator2
          pluginIds.systray
          pluginIds.separator3
          pluginIds.audio
          pluginIds.separator4
          pluginIds.voxtype
          pluginIds.separator5
          pluginIds.clock
          pluginIds.separator6
          pluginIds.power
        ];

        # Plugin Types
        "plugins/plugin-${toString pluginIds.menu}" = "applicationsmenu";
        "plugins/plugin-${toString pluginIds.tasklist}" = "tasklist";
        "plugins/plugin-${toString pluginIds.separator1}" = "separator";
        "plugins/plugin-${toString pluginIds.workspaces}" = "pager";
        "plugins/plugin-${toString pluginIds.separator2}" = "separator";
        "plugins/plugin-${toString pluginIds.systray}" = "systray";
        "plugins/plugin-${toString pluginIds.separator3}" = "separator";
        "plugins/plugin-${toString pluginIds.audio}" = "pulseaudio";
        "plugins/plugin-${toString pluginIds.separator4}" = "separator";
        "plugins/plugin-${toString pluginIds.voxtype}" = "genmon";
        "plugins/plugin-${toString pluginIds.separator5}" = "separator";
        "plugins/plugin-${toString pluginIds.clock}" = "clock";
        "plugins/plugin-${toString pluginIds.separator6}" = "separator";
        "plugins/plugin-${toString pluginIds.power}" = "actions";

        # Individual Plugin Settings
        # **************************

        # Tasklist
        # --------
        # We want our windows to group together
        # Behaviour: Group windows by application
        "plugins/plugin-${toString pluginIds.tasklist}/grouping" = 1;
        # Separator 1 is set to expand, so taskbar has space to expand into
        # Appearance: Expand
        "plugins/plugin-${toString pluginIds.separator1}/expand" = true;

        # Separators
        # ----------
        # We want all our separators to be transparent
        # Appearance: Style: Transparent
        "plugins/plugin-${toString pluginIds.separator1}/style" = 0;
        "plugins/plugin-${toString pluginIds.separator2}/style" = 0;
        "plugins/plugin-${toString pluginIds.separator3}/style" = 0;
        "plugins/plugin-${toString pluginIds.separator4}/style" = 0;
        "plugins/plugin-${toString pluginIds.separator5}/style" = 0;
        "plugins/plugin-${toString pluginIds.separator6}/style" = 0;

        # Voxtype
        # -------
        # A coloured dot showing the state of voxtype:
        # - Red = recording
        # - Yellow = transcribing
        # - Green = ready
        # - Hollow = unloaded
        # - Purple = unknown
        # Clicking it stops or starts the service.
        # Command
        "plugins/plugin-${toString pluginIds.voxtype}/command" = "${voxtypeIndicator}";
        # Period (s) in the dialog, but milliseconds here. Worst-case lag
        # between hitting the shortcut and the dot changing colour.
        "plugins/plugin-${toString pluginIds.voxtype}/update-period" = 100;
        # We want only the dot, no "Genmon" label next to it
        # Label
        "plugins/plugin-${toString pluginIds.voxtype}/use-label" = false;

        # Audio
        # -----
        # We want do NOT want keyboard controls for volume, playback, etc, as they do
        # not provide the desired control and granuality. Instead keyboard controls are
        # done manually as keyboard shortcuts in shortcuts.nix.
        # General: Behaviour: Enable keyboard shortcuts for volume control
        "plugins/plugin-${toString pluginIds.audio}/enable-keyboard-shortcuts" = false;
        # We want as much granuality as possible on the volume step
        # General: Behaviour: Volume step
        "plugins/plugin-${toString pluginIds.audio}/volume-step" = 1;
        # We do not wanna peak volume above 100%
        # General: Behaviour: Maximum volume
        "plugins/plugin-${toString pluginIds.audio}/volume-max" = 100;

        # Clock
        # -----
        # We want the clock to be digital (with seconds) and to show the date in ISO format
        # Appearance: Layout: Digital
        "plugins/plugin-${toString pluginIds.clock}/mode" = 2;
        # Clock Options: Layout: "Date, then time"
        "plugins/plugin-${toString pluginIds.clock}/digital-layout" = 0;
        # Clock Options: Date: Format: "YYYY-MM-DD"
        "plugins/plugin-${toString pluginIds.clock}/digital-date-format" = "%Y-%m-%d";
        # Clock Options: Time: Format: "HH:MM:SS"
        "plugins/plugin-${toString pluginIds.clock}/digital-time-format" = "%H:%M:%S";

        # Actions
        # -------
        # We want the actions menu to show the full name, giving the defined options when clicked
        # General: Appearance: Session Menu (1)
        "plugins/plugin-${toString pluginIds.power}/appearance" = 1;
        # General: Title: Full Name (0)
        "plugins/plugin-${toString pluginIds.power}/button-title" = 0;
        # Actions: List
        "plugins/plugin-${toString pluginIds.power}/items" = [
          "+lock-screen"
          "-switch-user"  # Disabled as we only have 1 user
          "+separator"
          "+suspend"
          "-hibernate"  # Disabled as we need swap
          "-hybrid-sleep"  # Disabled as we need swap
          "+separator"
          "+shutdown"
          "+restart"
          "+separator"
          "+logout"
          "-logout-dialog"  # Disabled as all options are covered by others
        ];
        # Actions: Show confirmation dialog
        "plugins/plugin-${toString pluginIds.power}/ask-confirmation" = true;
      };
    };
  };
}

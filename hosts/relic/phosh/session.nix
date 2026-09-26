{...}: {
  services.xserver.desktopManager.phosh = {
    enable = true;
    # phosh.service runs as this user and group. There is no greeter, so this
    # is the only user that can use the phone UI.
    user = "emil";
    group = "users";

    # Rendered to /etc/phosh/phoc.ini. The module default is a scale of 2,
    # which on the OnePlus 6 (1080x2280, ~400 dpi) gives a 540 px wide logical
    # screen; 2.5 gives 432 px, 3 gives 360 px (what phone apps are designed
    # for). Try values live with `wlr-randr --output DSI-1 --scale 3`, and
    # check the connector name with `wlr-randr` first.
    phocConfig.outputs.DSI-1.scale = 2.5;
  };

  users.users.emil.extraGroups = [
    "dialout" # modem serial ports (as in the Mobile NixOS phosh example)
    "feedbackd" # haptics, LED and sounds; created by programs.feedbackd
    "video" # backlight
  ];

  # Phosh is a GeoClue agent (it asks per app for location access) and
  # registers as "sm.puri.Phosh", which is not in the default whitelist of
  # GNOME Shell agents. geoclue2 itself is enabled by the GNOME services the
  # phosh module pulls in.
  services.geoclue2.whitelistedAgents = ["sm.puri.Phosh"];

  # iio-sensor-proxy, which Phosh uses for auto-rotation, ambient light and
  # proximity (screen off during calls).
  # NOTE: none of these work yet on the OnePlus 6: its sensors sit behind the
  # SLPI DSP and need hexagonrpcd serving the OnePlus sensor registry, which
  # relic does not have.
  hardware.sensor.iio.enable = true;

  # Phosh handles the power key itself (blank and lock, long press for the
  # power menu). Whenever it is not running (during boot, or if the session
  # crashes) logind's default is to power off on a short press.
  services.logind.settings.Login.HandlePowerKey = "ignore";

  # The Hall sensor (magnetic flip covers, magnetic mounts) shows up as a lid
  # switch, and logind's default would suspend the phone when it "closes",
  # missing calls and SMS. Phosh keeps suspend off by default (experimental).
  services.logind.settings.Login.HandleLidSwitch = "ignore";
}

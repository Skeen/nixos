{lib, ...}: {
  # Phosh ships phone-specific defaults for GNOME settings in its
  # 00_mobi.Phosh.gschema.override (`[<schema>:Phosh]` groups). NixOS keeps
  # every package's settings schemas in their own directory, so those
  # overrides only reach phosh's own `sm.puri.*` schemas; the ones for
  # `org.gnome.*` schemas are silently dropped. Re-create them (minus the
  # /usr/share wallpapers) as system dconf defaults, which the Settings app
  # can still change per user.
  # https://gitlab.gnome.org/World/Phosh/phosh/-/blob/main/data/00_mobi.Phosh.gschema.override
  # The on-screen keyboard one, screen-keyboard-enabled, is in ./keyboard.nix.
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/interface" = {
          accent-color = "yellow";
          clock-show-date = false;
          clock-show-weekday = false;
          color-scheme = "prefer-dark";
        };
        "org/gnome/desktop/session" = {
          # Blank the screen after one minute of inactivity
          idle-delay = lib.gvariant.mkUint32 60;
        };
        "org/gnome/settings-daemon/plugins/power" = {
          # Phosh does both itself
          ambient-enabled = false;
          power-button-action = "nothing";
        };
        "org/gnome/settings-daemon/plugins/wwan" = {
          # Ask for the SIM PIN
          unlock-sim = true;
        };
      };
    }
  ];
}

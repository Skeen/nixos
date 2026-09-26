{lib, ...}: {
  # On-screen keyboard (OSK). The phosh module installs stevia (formerly
  # phosh-osk-stub), which gnome-session starts as the systemd user unit
  # `mobi.phosh.OSK.service`.
  # https://gitlab.gnome.org/World/Phosh/stevia
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        # Phosh treats the OSK as unavailable while this is false, which is
        # the GNOME default. See ./gsettings.nix for why Phosh's own default
        # (true) never applies on NixOS.
        "org/gnome/desktop/a11y/applications" = {
          screen-keyboard-enabled = true;
        };
        # Both phoc (hardware keyboards) and stevia take their layout from
        # here, and stevia has a Danish layout.
        "org/gnome/desktop/input-sources" = {
          sources = [(lib.gvariant.mkTuple ["xkb" "dk"])];
        };
      };
    }
  ];

  # The GNOME services that the phosh module enables also turn on IBus (with
  # mkDefault), which exports GTK_IM_MODULE=ibus and QT_IM_MODULE=ibus. Apps
  # then talk to IBus instead of phoc's text-input protocol, which is what
  # makes the OSK unfold by itself when a text field is focused.
  i18n.inputMethod.enable = false;
}

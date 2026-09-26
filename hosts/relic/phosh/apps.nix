{pkgs, ...}: {
  # Phone apps

  # GNOME Calls (dialer). Also registers callaudiod, which switches the audio
  # profile for calls (there is no call audio on relic yet, see
  # ../network.nix), and autostarts a daemon so incoming calls ring. Uses
  # ModemManager.
  programs.calls.enable = true;

  # chatty (SMS/MMS, plus XMPP and Matrix) still depends on libolm, which is
  # marked insecure (it is deprecated, and its crypto has known timing side
  # channels). olm is only used for Matrix end-to-end encryption, so accept
  # it as long as no Matrix account is added to chatty.
  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16"];

  environment.systemPackages = with pkgs; [
    chatty # SMS

    # Firefox with postmarketOS' mobile-config-firefox (mobile UI, prefs and
    # policies). Installed directly: `programs.firefox.package =
    # pkgs.firefox-mobile` fails to evaluate, as programs.firefox calls
    # `.override { cfg = ...; }`, which firefox-mobile does not accept.
    firefox-mobile

    gnome-contacts # contacts, used by Calls and chatty
    gnome-console # terminal
    gnome-clocks # alarms and timers
    gnome-calculator
    gnome-weather
    gnome-maps
    gnome-text-editor
    loupe # image viewer
    portfolio-filemanager # touch-friendly file manager
    phosh-mobile-settings # Phosh-specific settings (OSK, lock screen, ...)
    wlr-randr # try phoc output scales live

    # Camera apps build, but the OnePlus 6 sensors (IMX519/IMX376/IMX371)
    # have no driver in the 6.4 kernel Mobile NixOS uses.
    # snapshot
  ];

  # Phosh's favorites bar. Firefox's desktop file does not declare that it
  # adapts to phone screens, so it is also forced adaptive, otherwise the app
  # grid hides it in phone mode.
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "sm/puri/phosh" = {
          favorites = [
            "org.gnome.Calls.desktop"
            "sm.puri.Chatty.desktop"
            "firefox.desktop"
            "org.gnome.Contacts.desktop"
          ];
          force-adaptive = ["firefox.desktop"];
        };
      };
    }
  ];
}

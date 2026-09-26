{pkgs, ...}: {
  # The phosh module enables services.gnome.core-shell and core-os-services,
  # which turn on a desktop's worth of GNOME services. Switch off the ones that
  # only cost battery, RAM or attack surface on a phone.
  services.gnome = {
    gnome-initial-setup.enable = false; # first-login wizard
    gnome-remote-desktop.enable = false;
    gnome-user-share.enable = false;
    gnome-browser-connector.enable = false;
    rygel.enable = false; # UPnP/DLNA media server
    localsearch.enable = false; # file indexer (was tracker-miners)
    tinysparql.enable = false; # indexer database (was tracker)
  };
  services.dleyna.enable = false; # UPnP media discovery
  services.hardware.bolt.enable = false; # Thunderbolt
  services.colord.enable = false; # colour profiles
  # These are enabled with mkDefault as well, so a mkDefault false conflicts;
  # use plain definitions.
  services.avahi.enable = false; # mDNS
  services.speechd.enable = false; # speech-dispatcher

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
    # Screen reader. Excluding it turns services.orca off, which otherwise
    # forces services.speechd.enable = true.
    orca
  ];
}

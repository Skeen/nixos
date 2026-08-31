# Housekeeping: journal retention + a periodic nix garbage collect.
{pkgs, ...}: {
  # Limit journal retention to 7 days to prevent disk exhaustion
  services.journald.extraConfig = ''
    MaxRetentionSec=7day
  '';

  # Reap old nix store entries between image rebuilds
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}

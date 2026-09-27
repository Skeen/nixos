# Housekeeping: journal retention + a periodic nix garbage collect.
{...}: {
  # The home directory shares its btrfs volume with /nix, and gamescope-session
  # deletes the oldest installed games when less than 500 MiB is left in ~.
  # Keep old system generations and logs from eating into that space.

  # Limit journal retention to 7 days to prevent disk exhaustion
  services.journald.extraConfig = ''
    MaxRetentionSec=7day
  '';

  # Reap old nix store entries left behind by past generations
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}

{ config, secrets, ... }: {
  services.restic.backups = {
    stronghold-server-backup = {
      # Initialize the repository, this is required even if the bucket exists.
      # Initialization means adding data, index, keys and snapshot folders.
      initialize = true;

      repository = "b2:stronghold-server-backup";

      timerConfig = {
        # Run the backup daily
        OnCalendar = "daily";
        # And at next startup if the server was offline
        Persistent = true;
      };

      # TODO: These are very generous, adjust if too expensive
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];

      # Files containing your secrets
      environmentFile = config.age.secrets.backblaze-environment-file.path;
      passwordFile = config.age.secrets.restic-password-file.path;

      paths = [
        "/nix/syncthing/data/"
      ];
    };
  };

  age.secrets.backblaze-environment-file = {
    file = "${secrets}/secrets/stronghold-backblaze-application-key.env.age";
    mode = "400";
    owner = "root";
    group = "root";
  };

  age.secrets.restic-password-file = {
    file = "${secrets}/secrets/stronghold-restic-password.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

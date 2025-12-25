{
  secrets,
  config,
  ...
}: let
  base_dir = "/nix/synapse";
  data_dir = "${base_dir}/data";
  db_data_dir = "${base_dir}/db";
  db_backup_dir = "${base_dir}/backup";
in {
  # NOTE: The matrix-synapse user is created by the matrix-synapse service
  # NOTE: The postgres user is created by the postgresql service

  # Create the data folder
  systemd.tmpfiles.rules = [
    "d ${base_dir} 0750 matrix-synapse matrix-synapse -"
    "d ${data_dir} 0750 matrix-synapse matrix-synapse -"
    "d ${db_data_dir} 0750 postgres postgres -"
    "d ${db_backup_dir} 0750 postgres postgres -"
  ];

  # https://element-hq.github.io/synapse/latest/
  # https://nixos.org/manual/nixos/stable/#module-services-matrix
  # https://wiki.nixos.org/wiki/Matrix
  # https://federationtester.matrix.org
  services.matrix-synapse = {
    enable = true;

    # This is the directory created above
    dataDir = data_dir;

    # https://element-hq.github.io/synapse/latest/usage/configuration/index.html
    settings = {
      # The server_name name appears at the end of usernames and room addresses
      # created on the server. It should NOT be a matrix-specific subdomain
      # such as matrix.example.com. Caddy *does* however serve synapse on
      # matrix.awful.engineer (rather than awful.engineer directly). This is
      # done through /.well-known/matrix delegation.
      # https://element-hq.github.io/synapse/latest/delegate.html.
      server_name = "awful.engineer";
      # The public-facing base URL that clients use to access this Homeserver.
      # This is the same URL a user might enter into the 'Custom Homeserver
      # URL' field on their client. If you use Synapse with a reverse proxy,
      # this should be the URL to reach Synapse via the proxy.
      public_baseurl = "https://matrix.awful.engineer";
      listeners = [
        {
          port = 8008;
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              # Enable client-server and server-server APIs
              names = ["client" "federation"];
            }
          ];
        }
      ];
      # Disable trusting signing keys from matrix.org (the default). If set to
      # the empty array, then Synapse will request the keys directly from the
      # server that owns the keys.
      # TODO: This is disabled (so we implicitly trust matrix.org) since,
      # apparently, the matrix protocol isn't distributed at all and nothing
      # works if you don't do this.
      # trusted_key_servers = [];
    };
  };

  services.postgresql = {
    enable = true;

    dataDir = db_data_dir;

    initdbArgs = [
      "--encoding=UTF-8"
      # matrix-synapse expects the database to have the options `LC_COLLATE`
      # and `LC_CTYPE` set to `C`, which basically instructs postgres to
      # ignore any locale-based preferences.
      "--lc-collate=C"
      "--lc-ctype=C"
    ];

    ensureDatabases = [
      "matrix-synapse"
    ];
    ensureUsers = [
      # If the database user name equals the connecting system user name,
      # postgres by default will accept a passwordless connection via unix
      # domain socket. This makes it possible to run many postgres-backed
      # services without creating any database secrets at all.
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }
    ];
  };

  services.postgresqlBackup = {
    enable = true;

    location = db_backup_dir;
    backupAll = true;
  };

  services.restic.backups = {
    stronghold-matrix-backup = {
      # Initialize the repository, this is required even if the bucket exists.
      # Initialization means adding data, index, keys and snapshot folders.
      initialize = true;

      repository = "b2:stronghold-synapse-backup";

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
      environmentFile = config.age.secrets.stronghold-synapse-backblaze-application-key-env-file.path;
      passwordFile = config.age.secrets.stronghold-synapse-restic-password-file.path;

      paths = [
        data_dir
        db_backup_dir
      ];
    };
  };

  age.secrets.stronghold-synapse-backblaze-application-key-env-file = {
    file = "${secrets}/secrets/stronghold-synapse-backblaze-application-key.env.age";
    mode = "400";
    owner = "root";
    group = "root";
  };

  age.secrets.stronghold-synapse-restic-password-file = {
    file = "${secrets}/secrets/stronghold-synapse-restic-password.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

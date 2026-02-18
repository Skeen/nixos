# https://element-hq.github.io/synapse/latest/
# https://nixos.org/manual/nixos/stable/#module-services-matrix
# https://wiki.nixos.org/wiki/Matrix
# https://federationtester.matrix.org
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
  # Create the matrix-synapse user and group
  users.users.matrix-synapse = {
    isSystemUser = true;
    group = "matrix-synapse";
    uid = config.ids.uids.matrix-synapse;
  };
  users.groups.matrix-synapse = {
    gid = config.ids.gids.matrix-synapse;
  };

  # Create the postgres user and group
  users.users.postgres = {
    isSystemUser = true;
    group = "postgres";
    uid = config.ids.uids.postgres;
  };
  users.groups.postgres = {
    gid = config.ids.gids.postgres;
  };

  # Create the data directories with their corresponding users
  systemd.tmpfiles.rules = [
    "d ${base_dir} 0750 root root -"
    "d ${data_dir} 0750 matrix-synapse matrix-synapse -"
    "d ${db_data_dir} 0750 postgres postgres -"
    "d ${db_backup_dir} 0750 postgres postgres -"
  ];

  # Networking: NAT for container internet access
  # This is required for synapse to call other homeservers
  networking.nat = {
    enable = true;
    internalInterfaces = ["ve-synapse"];
    externalInterface = "enp1s0"; # Check your interface with `ip link`!
  };

  # Synapse: Restic backup secrets
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
  # Synapse: Secrets
  age.secrets.stronghold-synapse-secrets-yaml-file = {
    file = "${secrets}/secrets/stronghold-synapse-secrets.yaml.age";
    mode = "400";
    owner = "matrix-synapse";
    group = "matrix-synapse";
  };

  containers.synapse = let
    synapse_data_dir = "/var/lib/matrix-synapse";
    postgres_data_dir = "/var/lib/postgresql";
    postgres_backup_dir = "/var/backup/postgresql";

    restic_secret_b2 = "/etc/synapse_backblaze.env";
    restic_secret_enc = "/etc/synapse_restic.pwd";
    synapse_secret_yaml = "/etc/synapse_secret.yaml";
  in {
    autoStart = true;

    # Isolate the network so the services cannot be reached from the internet
    # This is desirable as we will expose the service via Caddy
    privateNetwork = true;
    hostAddress = "192.168.100.10";
    localAddress = "192.168.100.13";
    forwardPorts = [];

    # Bind mount host data directories (writeable) and secret files (readonly)
    bindMounts = {
      "${synapse_data_dir}" = {
        hostPath = data_dir;
        isReadOnly = false;
      };
      "${postgres_data_dir}" = {
        hostPath = db_data_dir;
        isReadOnly = false;
      };
      "${postgres_backup_dir}" = {
        hostPath = db_backup_dir;
        isReadOnly = false;
      };
      # Secrets
      "${restic_secret_b2}" = {
        hostPath = config.age.secrets.stronghold-synapse-backblaze-application-key-env-file.path;
        isReadOnly = true;
      };
      "${restic_secret_enc}" = {
        hostPath = config.age.secrets.stronghold-synapse-restic-password-file.path;
        isReadOnly = true;
      };
      "${synapse_secret_yaml}" = {
        hostPath = config.age.secrets.stronghold-synapse-secrets-yaml-file.path;
        isReadOnly = true;
      };
    };

    config = {
      config,
      pkgs,
      ...
    }: {
      system.stateVersion = "25.05";

      # Open the container firewall for:
      networking.firewall.allowedTCPPorts = [
        # The ClientAPI and Federation API
        8008
        # 8448
        # Sliding Sync Proxy (MSC3575)
        # 8009
      ];

      services.matrix-synapse = {
        enable = true;

        # This is the directory created above
        dataDir = synapse_data_dir;

        # https://element-hq.github.io/synapse/latest/usage/configuration/index.html
        settings = {
          # The server_name name appears at the end of usernames and room addresses
          # created on the server. It generally should NOT be a matrix-specific
          # subdomain such as matrix.example.com, however in our case it is, since it
          # was misconfigured originally and is not easily corrected.
          # Caddy *does* however serve synapse on matrix.awful.engineer
          # (rather than awful.engineer directly). This is done through
          # /.well-known/matrix delegation.
          # https://element-hq.github.io/synapse/latest/delegate.html.
          server_name = "matrix.awful.engineer";
          # The public-facing base URL that clients use to access this Homeserver.
          # This is the same URL a user might enter into the 'Custom Homeserver
          # URL' field on their client. If you use Synapse with a reverse proxy,
          # this should be the URL to reach Synapse via the proxy.
          public_baseurl = "https://matrix.awful.engineer";
          listeners = [
            # Enable client API and Federation API
            {
              bind_addresses = [ "0.0.0.0" ];
              port = 8008;
              type = "http";
              tls = false;
              x_forwarded = true;
              resources = [
                {
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

          enable_registration = false;
          admin_contact = "mailto:synapse_admin_contac.endearing574@passmail.net";
        };

        extraConfigFiles = [
          synapse_secret_yaml 
        ];
      };

      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_14;

        dataDir = postgres_data_dir;

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

        location = postgres_backup_dir;
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
          environmentFile = restic_secret_b2;
          passwordFile = restic_secret_enc;

          paths = [
            synapse_data_dir
            postgres_backup_dir
          ];
        };
      };
    };
  };
}

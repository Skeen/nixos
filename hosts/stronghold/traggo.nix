# Traggo is a tag-based time tracking tool
# https://github.com/traggo/server
{
  traggo,
  thyme,
  config,
  secrets,
  pkgs,
  ...
}: let
  traggo_data_dir = "/nix/traggo";
  traggo_package = traggo.packages.${pkgs.system}.default;
  traggo_id = 43030;

  thyme_data_dir = "/nix/thyme";
  thyme_package = thyme.packages.${pkgs.system}.default;
  thyme_id = 43031;
in {
  # Create the traggo user and group
  users.users.traggo = {
    isSystemUser = true;
    group = "traggo";
    uid = traggo_id;
  };
  users.groups.traggo = {
    gid = traggo_id;
  };

  # Create the thyme user and group
  users.users.thyme = {
    isSystemUser = true;
    group = "thyme";
    uid = thyme_id;
  };
  users.groups.thyme = {
    gid = thyme_id;
  };

  # Create the data directories with their corresponding users
  systemd.tmpfiles.rules = [
    "d ${traggo_data_dir} 0700 traggo traggo -"
    "d ${thyme_data_dir} 0700 thyme thyme -"
  ];

  # Networking: NAT for container internet access
  # This is required for thyme to call Magentas redmine
  networking.nat = {
    enable = true;
    internalInterfaces = ["ve-traggo"];
    externalInterface = "enp1s0";
  };

  # Traggo: Admin user and password
  age.secrets.stronghold-traggo-env-file = {
    file = "${secrets}/secrets/stronghold-traggo.env.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
  # Traggo: Restic backup secrets
  age.secrets.stronghold-traggo-backblaze-application-key-env-file = {
    file = "${secrets}/secrets/stronghold-traggo-backblaze-application-key.env.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
  age.secrets.stronghold-traggo-restic-password-file = {
    file = "${secrets}/secrets/stronghold-traggo-restic-password.age";
    mode = "400";
    owner = "root";
    group = "root";
  };

  # Thyme: Traggo and Redmine API tokens
  age.secrets.stronghold-thyme-env-file = {
    file = "${secrets}/secrets/stronghold-thyme.env.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
  # Thyme: Restic backup secrets
  age.secrets.stronghold-thyme-backblaze-application-key-env-file = {
    file = "${secrets}/secrets/stronghold-thyme-backblaze-application-key.env.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
  age.secrets.stronghold-thyme-restic-password-file = {
    file = "${secrets}/secrets/stronghold-thyme-restic-password.age";
    mode = "400";
    owner = "root";
    group = "root";
  };

  containers.traggo = let
    traggo_base_dir = "/var/lib/traggo";
    traggo_secret_env = "/etc/traggo.env";
    traggo_secret_b2 = "/etc/traggo_backblaze.env";
    traggo_secret_restic = "/etc/traggo_restic.pwd";

    thyme_base_dir = "/var/lib/thyme";
    thyme_secret_env = "/etc/thyme.env";
    thyme_secret_b2 = "/etc/thyme_backblaze.env";
    thyme_secret_restic = "/etc/thyme_restic.pwd";
  in {
    autoStart = true;

    # Isolate the network so the services cannot be reached from the internet
    # This is desirable as we will expose the service via Caddy
    privateNetwork = true;
    hostAddress = "192.168.100.10";
    localAddress = "192.168.100.12";
    forwardPorts = [];

    # Bind mount host data directories (writeable) and secret files (readonly)
    bindMounts = {
      # Traggo binds
      "${traggo_base_dir}" = {
        hostPath = traggo_data_dir;
        isReadOnly = false;
      };
      "${traggo_secret_env}" = {
        hostPath = config.age.secrets.stronghold-traggo-env-file.path;
        isReadOnly = true;
      };
      "${traggo_secret_b2}" = {
        hostPath = config.age.secrets.stronghold-traggo-backblaze-application-key-env-file.path;
        isReadOnly = true;
      };
      "${traggo_secret_restic}" = {
        hostPath = config.age.secrets.stronghold-traggo-restic-password-file.path;
        isReadOnly = true;
      };
      # Thyme binds
      "${thyme_base_dir}" = {
        hostPath = thyme_data_dir;
        isReadOnly = false;
      };
      "${thyme_secret_env}" = {
        hostPath = config.age.secrets.stronghold-thyme-env-file.path;
        isReadOnly = true;
      };
      "${thyme_secret_b2}" = {
        hostPath = config.age.secrets.stronghold-thyme-backblaze-application-key-env-file.path;
        isReadOnly = true;
      };
      "${thyme_secret_restic}" = {
        hostPath = config.age.secrets.stronghold-thyme-restic-password-file.path;
        isReadOnly = true;
      };
    };

    config = {
      config,
      pkgs,
      ...
    }: {
      system.stateVersion = "25.05";

      # Open the container firewall for Traggo WebUI so Caddy can call it
      networking.firewall.allowedTCPPorts = [3030];

      # Create the traggo user and group
      users.users.traggo = {
        isSystemUser = true;
        group = "traggo";
        uid = traggo_id;
      };
      users.groups.traggo = {
        gid = traggo_id;
      };

      # Create the thyme user and group
      users.users.thyme = {
        isSystemUser = true;
        group = "thyme";
        uid = thyme_id;
      };
      users.groups.thyme = {
        gid = thyme_id;
      };

      # Install the traggo service
      systemd.services.traggo = {
        description = "Traggo time tracking";

        wants = ["network-online.target"];
        after = ["network-online.target"];

        # This ensures that the service is started when the container starts
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          User = "traggo";
          Group = "traggo";

          StateDirectory = "traggo";
          WorkingDirectory = traggo_base_dir;

          ExecStart = "${traggo_package}/bin/server";
          Restart = "always";
          RestartSec = "5s";

          EnvironmentFile = traggo_secret_env;
        };
      };

      services.restic.backups = {
        stronghold-traggo-backup = {
          # Initialize the repository, this is required even if the bucket exists.
          # Initialization means adding data, index, keys and snapshot folders.
          initialize = true;

          repository = "b2:stronghold-traggo-backup";

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
          environmentFile = traggo_secret_b2;
          passwordFile = traggo_secret_restic;

          paths = [
            traggo_base_dir
          ];
        };
      };

      # Install the thyme oneshot service
      systemd.services.thyme-sync = {
        description = "Thyme Traggo-to-Redmine Synchronization";
        wants = ["network-online.target"];
        after = ["network-online.target" "traggo.service"];
        requires = ["traggo.service"];

        environment = {
          TRAGGO_URL = "http://localhost:3030";
        };

        serviceConfig = {
          User = "thyme";
          Group = "thyme";

          StateDirectory = "thyme";
          WorkingDirectory = thyme_base_dir;

          Type = "oneshot";
          ExecStart = "${thyme_package}/bin/thyme";

          EnvironmentFile = thyme_secret_env;
        };
      };

      # Install the thyme timer triggering the oneshot service
      systemd.timers.thyme-sync = {
        description = "Timer for Thyme Daily Synchronization";
        wantedBy = ["timers.target"];
        partOf = ["thyme-sync.service"];

        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
      };

      services.restic.backups = {
        stronghold-thyme-backup = {
          # Initialize the repository, this is required even if the bucket exists.
          # Initialization means adding data, index, keys and snapshot folders.
          initialize = true;

          repository = "b2:stronghold-thyme-backup";

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
          environmentFile = thyme_secret_b2;
          passwordFile = thyme_secret_restic;

          paths = [
            thyme_base_dir
          ];
        };
      };
    };
  };
}

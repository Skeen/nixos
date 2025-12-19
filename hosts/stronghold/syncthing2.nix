{ config, pkgs, lib, secrets, ... }:
let
  # HOST-SIDE paths
  host_data_dir = "/nix/syncthing-data";
  
in {
  # ---------------------------------------------------------
  # 1. Host Configuration
  # ---------------------------------------------------------

  # Create the syncthing user and group on the host to simplify file permissions
  users.users.syncthing = {
    isSystemUser = true;
    group = "syncthing";
    uid = config.ids.uids.syncthing;
  };
  users.groups.syncthing = {
    gid = config.ids.gids.syncthing;
  };

  systemd.tmpfiles.rules = [
    "d ${host_data_dir} 0700 syncthing syncthing -"
  ];

  # Networking: NAT for container internet access
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-syncthing" ];
    externalInterface = "enp1s0"; # Check your interface with `ip link`!
  };

  # Host Secrets
  age.secrets.syncthing-cert = {
    file = "${secrets}/secrets/stronghold-syncthing-cert.age";
    mode = "400";
    owner = "syncthing";
    group = "syncthing";
  };
  age.secrets.syncthing-key = {
    file = "${secrets}/secrets/stronghold-syncthing-key.age";
    mode = "400";
    owner = "syncthing";
    group = "syncthing";
  };
  age.secrets.backblaze-environment-file = {
    file = "${secrets}/secrets/stronghold-syncthing-backblaze-application-key.env.age";
    mode = "400"; 
    owner = "syncthing";
    group = "syncthing";
  };
  age.secrets.restic-password-file = {
    file = "${secrets}/secrets/stronghold-syncthing-restic-password.age";
    mode = "400";
    owner = "syncthing";
    group = "syncthing";
  };

  # ---------------------------------------------------------
  # 2. Container Configuration
  # ---------------------------------------------------------

  containers.syncthing = let
    # CONTAINER-SIDE paths
    container_base_dir = "/var/lib/syncthing";
    container_data_dir = "${container_base_dir}/data";
    container_config_dir = "${container_base_dir}/config";
    
    # Secrets paths
    c_secret_cert = "/etc/syncthing-cert.pem";
    c_secret_key = "/etc/syncthing-key.pem";
    c_secret_b2 = "/etc/backblaze.env";
    c_secret_restic = "/etc/restic.pwd";
  in {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.10";
    localAddress = "192.168.100.11";

    forwardPorts = [
      # { hostPort = 8384; containerPort = 8384; protocol = "tcp"; }
      { hostPort = 22000; containerPort = 22000; protocol = "tcp"; }
      { hostPort = 22000; containerPort = 22000; protocol = "udp"; }
      { hostPort = 21027; containerPort = 21027; protocol = "udp"; }
    ];

    bindMounts = {
      "${container_base_dir}" = { hostPath = host_data_dir; isReadOnly = false; };
      "${c_secret_cert}" = { hostPath = config.age.secrets.syncthing-cert.path; isReadOnly = true; };
      "${c_secret_key}" = { hostPath = config.age.secrets.syncthing-key.path; isReadOnly = true; };
      "${c_secret_b2}" = { hostPath = config.age.secrets.backblaze-environment-file.path; isReadOnly = true; };
      "${c_secret_restic}" = { hostPath = config.age.secrets.restic-password-file.path; isReadOnly = true; };
    };

    config = { config, pkgs, ... }: {
      system.stateVersion = "25.05";

      systemd.tmpfiles.rules = [
        "d ${container_base_dir} 0750 syncthing syncthing -"
        "d ${container_data_dir} 0750 syncthing syncthing -"
        "d ${container_config_dir} 0750 syncthing syncthing -"
      ];

      services.syncthing = {
        enable = true;
        openDefaultPorts = true;
        user = "syncthing";
        group = "syncthing";
        dataDir = container_data_dir;
        configDir = container_config_dir;
        overrideDevices = true;
        overrideFolders = true;
        extraFlags = [ "--no-default-folder" ];
        cert = c_secret_cert;
        key = c_secret_key;

        settings = {
          devices = {
            "phone" = { id = "OG6NKQ2-FVN4NWE-AA7KI25-YNTCMTB-SK3V6SU-VET2KSH-G4ZAUU2-CLB22AR"; };
            "morphine" = { id = "JSEDIEO-N6KAZFG-YGXCNR5-VZS5JQM-NQFBEC2-UTPRCCY-GXNW2DX-TMNFSAD"; };
          };
          folders = {
            "phone_backup" = {
              path = "${container_data_dir}/phone_backup";
              devices = ["phone"];
            };
            "phone_pictures" = {
              path = "${container_data_dir}/phone_pictures";
              devices = ["phone" "morphine"];
              type = "receiveencrypted";
            };
          };
          options = { urAccepted = -1; };
        };
      };

      services.restic.backups.stronghold-syncthing-backup = {
        initialize = true;
        repository = "b2:stronghold-syncthing-backup";
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
        # Run as the syncthing user instead of root
        user = "syncthing";
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
        environmentFile = c_secret_b2;
        passwordFile = c_secret_restic;
        paths = [ container_data_dir ];
      };
    };
  };
}

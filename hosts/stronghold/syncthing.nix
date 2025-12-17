{config, secrets, ...}: {
  # Syncthing is a continuous file synchronization program. It synchronizes
  # files between two or more computers in real time. It's basically a
  # self-hosted Dropbox for Linux users, but without FTP, curlftpfs, and SVN.
  # https://wiki.nixos.org/wiki/Syncthing
  #
  # Access server's WebUI from desktop:
  # > ssh -L 9999:localhost:8384 stronghold

  # Create the syncthing user and group
  users.users.syncthing = {
    isSystemUser = true;
    group = "syncthing";
  };
  users.groups.syncthing = {};

  # Create the data folder
  systemd.tmpfiles.rules = [
    "d /nix/syncthing 0750 syncthing syncthing -"
  ];

  # Configure syncthing
  services.syncthing = {
    enable = true;

    # This opens the firewall ports for syncthing:
    # (22000 for data, 21027 for discovery)
    # NOTE: This does *not* expose the GUI (8384)
    openDefaultPorts = true;

    # This is the user and group created above
    user = "syncthing";
    group = "syncthing";

    # This is the directory created above
    dataDir = "/nix/syncthing/data";
    configDir = "/nix/syncthing/config";

    # Overrides changes done via the WebUI
    overrideDevices = true;
    overrideFolders = true;

    # Disable creating the default folder (~/Sync)
    extraFlags = [ "--no-default-folder" ];

    settings = {
      devices = {
        "phone" = { id = "OG6NKQ2-FVN4NWE-AA7KI25-YNTCMTB-SK3V6SU-VET2KSH-G4ZAUU2-CLB22AR"; };
        "morphine" = { id = "JSEDIEO-N6KAZFG-YGXCNR5-VZS5JQM-NQFBEC2-UTPRCCY-GXNW2DX-TMNFSAD"; };
      };
      folders = {
        "phone_backup" = {
          path = "/nix/syncthing/phone_backup/";
          devices = ["phone"];
          # NOTE: GrapheneOS backup is already encrypted on device
        };
        "phone_pictures" = {
          path = "/nix/syncthing/phone_pictures/";
          devices = ["phone" "morphine"];
          type = "receiveencrypted";
        };
      };

      options = {
        # Don't submit anonymous usage data
        urAccepted = -1;
      };
    };

    # https://wiki.nixos.org/wiki/Syncthing#Declarative_node_IDs
    cert = config.age.secrets.syncthing-cert.path;
    key = config.age.secrets.syncthing-key.path;
  };

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
}

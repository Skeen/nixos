# NetBird is a WireGuard based overlay network (VPN) with a control plane
# https://netbird.io
{
  config,
  lib,
  pkgs,
  secrets,
  nixpkgs-2605,
  ...
}: let
  domain = "netbird.awful.engineer";
  system = pkgs.stdenv.hostPlatform.system;
  data_dir = "/nix/netbird";
  address = "192.168.100.14";

  management_port = 8011;
  signal_port = 8012;
  relay_port = 33080;
  stun_port = 3478;
in {
  systemd.tmpfiles.rules = [
    "d ${data_dir} 0700 root root -"
  ];

  # Encrypts sensitive data in the management database
  age.secrets.stronghold-netbird-datastore-key-file = {
    file = "${secrets}/secrets/stronghold-netbird-datastore-key.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
  # Shared between management and relay, to authenticate peers to the relay
  age.secrets.stronghold-netbird-relay-secret-file = {
    file = "${secrets}/secrets/stronghold-netbird-relay-secret.age";
    mode = "400";
    owner = "root";
    group = "root";
  };

  # Networking: NAT for container internet access
  # Management downloads its geolocation database on first start
  networking.nat = {
    enable = true;
    internalInterfaces = ["ve-netbird"];
    externalInterface = "enp1s0";
  };

  # STUN, the only port not behind Caddy
  networking.firewall.allowedUDPPorts = [stun_port];

  services.caddy.virtualHosts.${domain}.extraConfig = ''
    handle /management.ManagementService/* {
      reverse_proxy h2c://${address}:${toString management_port}
    }
    handle /signalexchange.SignalExchange/* {
      reverse_proxy h2c://${address}:${toString signal_port}
    }
    handle /ws-proxy/signal* {
      reverse_proxy ${address}:${toString signal_port}
    }
    handle /relay* {
      reverse_proxy ${address}:${toString relay_port}
    }
    @management path /api/* /oauth2/* /ws-proxy/management*
    handle @management {
      reverse_proxy ${address}:${toString management_port}
    }
    handle {
      reverse_proxy ${address}:80
    }
  '';

  containers.netbird = let
    datastore_key = "/etc/netbird-datastore-key";
    relay_secret = "/etc/netbird-relay-secret";
  in {
    # NetBird from 26.05, which has the embedded identity provider (local
    # users) and the relay with built-in STUN
    nixpkgs = nixpkgs-2605;
    autoStart = true;

    # Isolate the network so the services cannot be reached from the internet
    # This is desirable as we will expose the service via Caddy
    privateNetwork = true;
    hostAddress = "192.168.100.10";
    localAddress = address;
    forwardPorts = [
      {
        protocol = "udp";
        hostPort = stun_port;
      }
    ];

    # Bind mount host data directories (writeable) and secret files (readonly)
    bindMounts = {
      "/var/lib/netbird-mgmt" = {
        hostPath = data_dir;
        isReadOnly = false;
      };
      "${datastore_key}" = {
        hostPath = config.age.secrets.stronghold-netbird-datastore-key-file.path;
        isReadOnly = true;
      };
      "${relay_secret}" = {
        hostPath = config.age.secrets.stronghold-netbird-relay-secret-file.path;
        isReadOnly = true;
      };
    };

    config = {pkgs, ...}: {
      system.stateVersion = "26.05";

      # The container module passes the host's platform, as elaborated by the
      # host's 25.05 lib, which changes every hash (no binary cache hits)
      nixpkgs.hostPlatform = lib.mkForce system;

      # Limit journal retention to 7 days
      services.journald.extraConfig = ''
        MaxRetentionSec=7day
      '';

      # Open the container firewall for the services Caddy calls, and STUN
      networking.firewall.allowedTCPPorts = [80 management_port signal_port relay_port];
      networking.firewall.allowedUDPPorts = [stun_port];

      services.netbird.server = {
        inherit domain;
        enable = true;

        # Only the dashboard gets nginx, as a static file server for Caddy
        dashboard = {
          enableNginx = true;
          settings = {
            AUTH_AUTHORITY = "https://${domain}/oauth2";
            AUTH_AUDIENCE = "netbird-dashboard";
            AUTH_CLIENT_ID = "netbird-dashboard";
            AUTH_SUPPORTED_SCOPES = "openid profile email groups";
            AUTH_REDIRECT_URI = "/nb-auth";
            AUTH_SILENT_REDIRECT_URI = "/nb-silent-auth";
            NETBIRD_TOKEN_SOURCE = "accessToken";
          };
        };

        management = {
          port = management_port;
          turnDomain = domain;
          # Overridden by the embedded identity provider
          oidcConfigEndpoint = "https://${domain}/oauth2/.well-known/openid-configuration";
          settings = {
            # Local users with passwords, instead of an external provider
            EmbeddedIdP = {
              Enabled = true;
              Issuer = "https://${domain}/oauth2";
              DashboardRedirectURIs = [
                "https://${domain}/nb-auth"
                "https://${domain}/nb-silent-auth"
              ];
            };
            DataStoreEncryptionKey._secret = datastore_key;
            Relay = {
              Addresses = ["rels://${domain}:443/relay"];
              CredentialsTTL = "24h";
              Secret._secret = relay_secret;
            };
            # The relay replaces TURN
            TURNConfig = {
              Turns = [];
              Secret._secret = relay_secret;
            };
            ReverseProxy.TrustedHTTPProxies = ["192.168.100.10/32"];
          };
        };

        signal.port = signal_port;
      };

      # 26.05 has no module for the relay
      systemd.services.netbird-relay = {
        description = "The relay server for NetBird";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];
        script = ''
          export NB_AUTH_SECRET="$(< "$CREDENTIALS_DIRECTORY/auth-secret")"
          exec ${pkgs.netbird-relay}/bin/netbird-relay \
            --listen-address :${toString relay_port} \
            --exposed-address rels://${domain}:443/relay \
            --enable-stun --stun-ports ${toString stun_port} \
            --metrics-port 9092
        '';
        serviceConfig = {
          DynamicUser = true;
          LoadCredential = "auth-secret:${relay_secret}";
          Restart = "always";
        };
      };
    };
  };
}

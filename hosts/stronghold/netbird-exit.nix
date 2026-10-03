# NetBird exit nodes that send traffic out through Mullvad
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

  # Mullvad's default route lives in this table; wireguard tags its own packets
  # with the same number so the policy rule below can let them out
  mullvadTable = 100;

  # One Mullvad device each: two peers sharing a key fight over the one session
  exits = {
    exit-dk = {
      localAddress = "192.168.100.15";
      wgKeyFile = config.age.secrets.stronghold-mullvad-dk-wg-private-key-file.path;
      setupKeyFile = config.age.secrets.stronghold-netbird-exit-dk-setup-key-file.path;
      # Device "fair fox"
      mullvadAddress = ["10.74.114.8/32" "fc00:bbbb:bbbb:bb01::b:7207/128"];
      # dk-cph-wg-002
      peerPublicKey = "R5LUBgM/1UjeAR4lt+L/yA30Gee6/VqVZ9eAB3ZTajs=";
      peerEndpoint = "45.129.56.68:51820";
    };
    exit-sg = {
      localAddress = "192.168.100.16";
      wgKeyFile = config.age.secrets.stronghold-mullvad-sg-wg-private-key-file.path;
      setupKeyFile = config.age.secrets.stronghold-netbird-exit-sg-setup-key-file.path;
      # Device "noble dog"
      mullvadAddress = ["10.75.198.14/32" "fc00:bbbb:bbbb:bb01::c:c60d/128"];
      # sg-sin-wg-003
      peerPublicKey = "3HtGdhEXUPKQIDRW49wCUoTK2ZXfq+QfzjfYoldNchg=";
      peerEndpoint = "138.199.60.28:51820";
    };
  };
in {
  age.secrets = {
    stronghold-mullvad-dk-wg-private-key-file = {
      file = "${secrets}/secrets/stronghold-mullvad-dk-wg-private-key.age";
      # systemd-networkd reads PrivateKeyFile as the systemd-network user
      mode = "440";
      owner = "root";
      group = "systemd-network";
    };
    stronghold-mullvad-sg-wg-private-key-file = {
      file = "${secrets}/secrets/stronghold-mullvad-sg-wg-private-key.age";
      # systemd-networkd reads PrivateKeyFile as the systemd-network user
      mode = "440";
      owner = "root";
      group = "systemd-network";
    };
    stronghold-netbird-exit-dk-setup-key-file = {
      file = "${secrets}/secrets/stronghold-netbird-exit-dk-setup-key.age";
      mode = "400";
      owner = "root";
      group = "root";
    };
    stronghold-netbird-exit-sg-setup-key-file = {
      file = "${secrets}/secrets/stronghold-netbird-exit-sg-setup-key.age";
      mode = "400";
      owner = "root";
      group = "root";
    };
  };

  # Reaching Mullvad and the management API goes out through the host
  networking.nat = {
    enable = true;
    internalInterfaces = lib.mapAttrsToList (name: _: "ve-${name}") exits;
    externalInterface = "enp1s0";
  };

  containers =
    lib.mapAttrs' (
      name: exit:
        lib.nameValuePair name (let
          mullvad_key = "/etc/mullvad-wg-private-key";
          setup_key = "/etc/netbird-setup-key";
        in {
          # 25.05's netbird module has no routing features
          nixpkgs = nixpkgs-2605;
          autoStart = true;

          privateNetwork = true;
          hostAddress = "192.168.100.10";
          localAddress = exit.localAddress;

          # Both WireGuard and NetBird create tunnel interfaces in here
          enableTun = true;

          bindMounts = {
            "${mullvad_key}" = {
              hostPath = exit.wgKeyFile;
              isReadOnly = true;
            };
            "${setup_key}" = {
              hostPath = exit.setupKeyFile;
              isReadOnly = true;
            };
          };

          config = {...}: {
            system.stateVersion = "26.05";

            # The container module passes the host's platform, as elaborated by
            # the host's 25.05 lib, which changes every hash (no cache hits)
            nixpkgs.hostPlatform = lib.mkForce system;

            networking.hostName = name;

            # Limit journal retention to 7 days
            services.journald.extraConfig = ''
              MaxRetentionSec=7day
            '';

            networking.useNetworkd = true;

            # useNetworkd turns resolved on, which would claim resolv.conf
            services.resolved.enable = false;

            # nixos-containers configures eth0 itself before networkd starts
            systemd.network.networks."10-eth0" = {
              matchConfig.Name = "eth0";
              linkConfig.Unmanaged = true;
            };

            systemd.network.netdevs."20-mullvad" = {
              netdevConfig = {
                Name = "mullvad";
                Kind = "wireguard";
              };
              wireguardConfig = {
                PrivateKeyFile = mullvad_key;
                FirewallMark = mullvadTable;
                RouteTable = mullvadTable;
              };
              wireguardPeers = [
                {
                  PublicKey = exit.peerPublicKey;
                  Endpoint = exit.peerEndpoint;
                  AllowedIPs = ["0.0.0.0/0" "::/0"];
                  # Keeps the host's conntrack entry for this tunnel from expiring
                  PersistentKeepalive = 25;
                }
              ];
            };

            systemd.network.networks."20-mullvad" = {
              matchConfig.Name = "mullvad";
              address = exit.mullvadAddress;
              routingPolicyRules = [
                # Main minus its default route, so DNS to the host survives
                {
                  Table = "main";
                  SuppressPrefixLength = 0;
                  Priority = 32764;
                  Family = "both";
                }
                # Everything else to Mullvad, except WireGuard's own traffic
                {
                  Table = mullvadTable;
                  FirewallMark = mullvadTable;
                  InvertRule = true;
                  Priority = 32765;
                  Family = "both";
                }
              ];
            };

            services.netbird = {
              enable = true;
              # Enables IP forwarding, to act as a route for other peers
              useRoutingFeatures = "server";
              clients.default = {
                login.enable = true;
                login.setupKeyFile = setup_key;
                # Flags bind to NB_ variables, this is --management-url
                environment.NB_MANAGEMENT_URL = "https://${domain}";
              };
            };

            # Return traffic arrives on a different interface than it left
            networking.firewall.checkReversePath = "loose";
          };
        })
    )
    exits;
}

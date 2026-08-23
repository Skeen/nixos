{ config, secrets, ... }:
{
  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  systemd.network.netdevs."10-wghub" = {
    netdevConfig = {
      Kind = "wireguard";
      Name = "wghub";
    };
    wireguardConfig = {
      PrivateKeyFile = config.age.secrets.stronghold-wg-private-key-file.path;
      ListenPort = 51820;
    };
    wireguardPeers = [
      # Granary
      {
        PublicKey = "qTXv/mcdkkJZExDj8XMYZeR5zKS3AYcA6Vnyz+bCMHI=";
        AllowedIPs = [ "192.168.50.2/32" ];
      }
      # Coffer
      {
        PublicKey = "0l71ocXjUZhntat9i7BxBPW2RWjSkWsGHeB+NGkP1Gk=";
        AllowedIPs = [ "192.168.50.3/32" ];
      }
    ];
  };

  systemd.network.networks."10-wghub" = {
    matchConfig.Name = "wghub";
    address = [ "192.168.50.1/24" ];
  };

  age.secrets.stronghold-wg-private-key-file = {
    file = "${secrets}/secrets/stronghold-wg-private-key.age";
    # systemd-networkd reads PrivateKeyFile as the systemd-network user
    mode = "440";
    owner = "root";
    group = "systemd-network";
  };
}

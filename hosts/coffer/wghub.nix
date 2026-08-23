{ config, secrets, ... }:
{
  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  networking.firewall.checkReversePath = "loose";

  systemd.network.netdevs."10-wghub" = {
    netdevConfig = {
      Kind = "wireguard";
      Name = "wghub";
    };
    wireguardConfig = {
      PrivateKeyFile = config.age.secrets.coffer-wg-private-key-file.path;
    };
    wireguardPeers = [
      # Stronghold
      {
        PublicKey = "NLGR5eXjC6Fq2tw7VFvrgl+CHDvHqmwvHXbfNaIfmVs=";
        AllowedIPs = [ "192.168.50.1/32" ];
        Endpoint = "awful.engineer:51820";
        PersistentKeepalive = 25;
      }
    ];
  };

  systemd.network.networks."10-wghub" = {
    matchConfig.Name = "wghub";
    address = [ "192.168.50.3/24" ];
  };

  age.secrets.coffer-wg-private-key-file = {
    file = "${secrets}/secrets/coffer-wg-private-key.age";
    # systemd-networkd reads PrivateKeyFile as the systemd-network user
    mode = "440";
    owner = "root";
    group = "systemd-network";
  };
}

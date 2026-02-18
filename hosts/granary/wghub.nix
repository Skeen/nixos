{ config, secrets, ... }:
{
  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  networking.wireguard.interfaces.wghub = {
    ips = [ "192.168.50.2/24" ];
    privateKeyFile = config.age.secrets.granary-wg-private-key-file.path;

    peers = [
      # Stronghold
      {
        publicKey = "NLGR5eXjC6Fq2tw7VFvrgl+CHDvHqmwvHXbfNaIfmVs=";
        allowedIPs = [ "192.168.50.1/32" ];
        endpoint = "awful.engineer:51820";
        persistentKeepalive = 25;
      }
    ];
  };

  age.secrets.granary-wg-private-key-file = {
    file = "${secrets}/secrets/granary-wg-private-key.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

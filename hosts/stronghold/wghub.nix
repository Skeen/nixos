{ config, secrets, ... }:
{
  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  networking.wireguard.interfaces.wghub = {
    ips = [ "192.168.50.1/24" ];
    listenPort = 51820;
    privateKeyFile = config.age.secrets.stronghold-wg-private-key-file.path;

    peers = [
      # Granary
      {
        publicKey = "qTXv/mcdkkJZExDj8XMYZeR5zKS3AYcA6Vnyz+bCMHI=";
        allowedIPs = [ "192.168.50.2/32" ];
      }
    ];
  };

  age.secrets.stronghold-wg-private-key-file = {
    file = "${secrets}/secrets/stronghold-wg-private-key.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

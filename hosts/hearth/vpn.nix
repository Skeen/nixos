{
  config,
  secrets,
  ...
}: {
  # "loose" allows return traffic on different interfaces, required for VPNs
  networking.firewall.checkReversePath = "loose";

  networking.wg-quick.interfaces = {
    dk-cph-wg-002 = {
      autostart = true;

      address = [
        "10.70.207.60/32"
        "fc00:bbbb:bbbb:bb01::7:cf3b/128"
      ];
      
      privateKeyFile = config.age.secrets.hearth-mullvad-wg-private-key-file.path;
 
      dns = [ "100.64.0.7" ];

      peers = [
        {
          publicKey = "R5LUBgM/1UjeAR4lt+L/yA30Gee6/VqVZ9eAB3ZTajs=";
          endpoint = "45.129.56.68:51820";
          allowedIPs = [ "0.0.0.0/0,::0/0" ];
          # Keepalive is crucial for clients behind NAT
          persistentKeepalive = 25;
        }
      ];
    };

    sg-sin-wg-003 = {
      autostart = false;

      address = [
        "10.70.207.60/32"
        "fc00:bbbb:bbbb:bb01::7:cf3b/128"
      ];
      
      privateKeyFile = config.age.secrets.hearth-mullvad-wg-private-key-file.path;
 
      dns = [ "100.64.0.7" ];

      peers = [
        {
          publicKey = "3HtGdhEXUPKQIDRW49wCUoTK2ZXfq+QfzjfYoldNchg=";
          endpoint = "138.199.60.28:51820";
          allowedIPs = [ "0.0.0.0/0,::0/0" ];
          # Keepalive is crucial for clients behind NAT
          persistentKeepalive = 25;
        }
      ];
    };

    us-nyc-wg-303 = {
      autostart = false;

      address = [
        "10.70.207.60/32"
        "fc00:bbbb:bbbb:bb01::7:cf3b/128"
      ];
      
      privateKeyFile = config.age.secrets.hearth-mullvad-wg-private-key-file.path;
 
      dns = [ "100.64.0.7" ];

      peers = [
        {
          publicKey = "KRO+RzrFV92Ah+qpHgAMKZH2jtjRlmJ4ayl0gletY3c=";
          endpoint = "143.244.47.91:51820";
          allowedIPs = [ "0.0.0.0/0,::0/0" ];
          # Keepalive is crucial for clients behind NAT
          persistentKeepalive = 25;
        }
      ];
    };
  };

  age.secrets.hearth-mullvad-wg-private-key-file = {
    file = "${secrets}/secrets/hearth-mullvad-wg-private-key.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

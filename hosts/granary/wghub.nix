{ pkgs, config, secrets, ... }:
{
  networking.firewall = {
    allowedUDPPorts = [ 51820 ];
  };

  networking.firewall.checkReversePath = "loose";

  networking.wireguard.interfaces.wghub = let
    stronghold_public_key = "NLGR5eXjC6Fq2tw7VFvrgl+CHDvHqmwvHXbfNaIfmVs=";
  in {
    ips = [ "192.168.50.2/24" ];
    privateKeyFile = config.age.secrets.granary-wg-private-key-file.path;

    peers = [
      # Stronghold
      {
        publicKey = stronghold_public_key;
        allowedIPs = [ "192.168.50.1/32" ];
        endpoint = "awful.engineer:51820";
        persistentKeepalive = 25;
      }
    ];
    # Due to a known NixOS issue, 'persistentKeepalive' is not respected in peers.
    # Thus we reapply it here to esnure it takes effect.
    # Without 'persistentKeepalive' the NAT will eventually close the connection,
    # and thus only granary can reach stronghold, not vice versa.
    # See: https://wiki.nixos.org/wiki/WireGuard#Tunnel_does_not_automatically_connect_despite_persistentKeepalive_being_set
    postSetup = "${pkgs.wireguard-tools}/bin/wg set wghub peer '${stronghold_public_key}' persistent-keepalive 25";
  };

  age.secrets.granary-wg-private-key-file = {
    file = "${secrets}/secrets/granary-wg-private-key.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

{...}: {
  # systemd-networkd manages all interfaces
  networking.useDHCP = false;
  networking.useNetworkd = true;

  systemd.network.networks."10-enp1s0" = {
    matchConfig.Name = "enp1s0";
    networkConfig.DHCP = "yes";
    address = [ "2a01:4f9:c013:7d2b::1/64" ];
    routes = [
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
    ];
  };

  # NixOS containers with privateNetwork = true
  # Use point-to-point addressing to match the legacy NixOS container networking
  systemd.network.networks."20-ve-synapse" = {
    matchConfig.Name = "ve-synapse";
    addresses = [
      {
        Address = "192.168.100.10/32";
        Peer = "192.168.100.13/32";
      }
    ];
  };

  systemd.network.networks."20-ve-traggo" = {
    matchConfig.Name = "ve-traggo";
    addresses = [
      {
        Address = "192.168.100.10/32";
        Peer = "192.168.100.12/32";
      }
    ];
  };

  systemd.network.networks."20-ve-syncthing" = {
    matchConfig.Name = "ve-syncthing";
    addresses = [
      {
        Address = "192.168.100.10/32";
        Peer = "192.168.100.11/32";
      }
    ];
  };
}

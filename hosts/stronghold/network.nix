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
  systemd.network.networks."20-ve-synapse" = {
    matchConfig.Name = "ve-synapse";
    networkConfig.Address = "192.168.100.10/24";
  };

  systemd.network.networks."20-ve-traggo" = {
    matchConfig.Name = "ve-traggo";
    networkConfig.Address = "192.168.100.10/24";
  };

  systemd.network.networks."20-ve-syncthing" = {
    matchConfig.Name = "ve-syncthing";
    networkConfig.Address = "192.168.100.10/24";
  };
}

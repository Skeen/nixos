{...}: {
  # systemd-networkd manages all interfaces
  networking.useDHCP = false;
  networking.useNetworkd = true;

  # Local DNS resolver for containers
  services.unbound = {
    enable = true;
    settings.server.interface = [ "192.168.100.10" ];
    settings.server.access-control = [ "192.168.100.0/24 allow" ];
  };

  # Use unbound for the host itself. Use the container-facing address so
  # containers can also use it when they copy the host's resolv.conf.
  networking.nameservers = [ "192.168.100.10" ];

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
  # Tell networkd to ignore these interfaces; the container post-start script
  # configures them itself. This avoids conflicts where both networkd and
  # the script try to add the same address.
  systemd.network.networks."20-ve-synapse" = {
    matchConfig.Name = "ve-synapse";
    linkConfig.Unmanaged = true;
  };

  systemd.network.networks."20-ve-traggo" = {
    matchConfig.Name = "ve-traggo";
    linkConfig.Unmanaged = true;
  };

  systemd.network.networks."20-ve-syncthing" = {
    matchConfig.Name = "ve-syncthing";
    linkConfig.Unmanaged = true;
  };
}

{...}: {
  # systemd-networkd manages all interfaces
  networking.useDHCP = false;
  networking.useNetworkd = true;

  # Local DNS resolver for the host and the containers
  services.unbound = {
    enable = true;
    settings.server.interface = [ "192.168.100.10" ];
    settings.server.access-control = [ "192.168.100.0/24 allow" ];
  };

  # Disable systemd-resolved so it doesn't manage /etc/resolv.conf
  services.resolved.enable = false;

  # Container queries reach unbound via the INPUT chain, which nat does not touch
  networking.firewall.interfaces."ve-+".allowedUDPPorts = [ 53 ];
  networking.firewall.interfaces."ve-+".allowedTCPPorts = [ 53 ];

  # Containers inherit this file, so it must not name 127.0.0.1: their
  # resolvconf drops every non-local server once a local one is present
  environment.etc."resolv.conf".text = ''
    nameserver 192.168.100.10
    options edns0
  '';

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

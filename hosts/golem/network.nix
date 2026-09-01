# Hetzner Cloud networking.
#
# DHCP-only until the server exists (its Hetzner-assigned IPv4 + IPv6 ranges
# will be pinned here once known, mirroring stronghold's network.nix):
# TODO: pin the /64 like stronghold's network.nix once known.
#
# The Kubernetes API port (6443) and the NodePort range stay behind the Hetzner
# firewall (configured in the Hetzner Cloud console), so only SSH + NodePorts
# need to reach the host.
{lib, ...}: {
  # systemd-networkd manages all interfaces (like stronghold)
  networking.useDHCP = false;
  networking.useNetworkd = true;

  # Plain DNS resolvers instead of systemd-resolved's 127.0.0.53 stub: the
  # coredns addon pod uses dnsPolicy=Default and copies the node's
  # /etc/resolv.conf, which would point at a loopback address inside its own
  # network namespace and silently break upstream DNS forwarding.
  services.resolved.enable = false;
  networking.resolvconf.useLocalResolver = false;
  # Static resolvers injected into resolvconf.conf (networkd's DHCP-provided
  # DNS does not reliably reach openresolv in the networkd-only setup).
  networking.resolvconf.extraConfig = ''
    name_servers='185.12.64.1 185.12.64.2 2a01:4ff:ff00::add:1 2a01:4ff:ff00::add:2'
  '';

  # Hetzner Cloud: the NIC is enp1s0 (PCI slot naming). VMs (e.g. the
  # golemVm test run) present the same interface as eth0, so match both.
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp1s0 eth0";
    networkConfig.DHCP = "yes";
    # Routed IPv6 via the link-local gateway (Hetzner style)
    routes = [
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
    ];
    linkConfig.RequiredForOnline = "routable";
  };

  # Don't let networkd manage flannel's / CNI-created interfaces.
  systemd.network.networks."20-cni" = {
    matchConfig.Name = "cni*";
    linkConfig.Unmanaged = true;
  };
  systemd.network.networks."20-mynet" = {
    matchConfig.Name = "mynet*";
    linkConfig.Unmanaged = true;
  };
  systemd.network.networks."20-flannel" = {
    matchConfig.Name = "flannel*";
    linkConfig.Unmanaged = true;
  };
}

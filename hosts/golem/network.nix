# Hetzner Cloud networking.
#
# DHCP-only for now. The DNS resolver hacks and the CNI/flannel interface
# exclusions that the Kubernetes work needs are deliberately absent: they are
# specific to running a cluster on this host and belong with that config.
{...}: {
  # systemd-networkd manages all interfaces (like stronghold)
  networking.useDHCP = false;
  networking.useNetworkd = true;

  # Hetzner Cloud: the NIC is enp1s0 (PCI slot naming). VMs (e.g. a local
  # test run) present the same interface as eth0, so match both.
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp1s0 eth0";
    networkConfig.DHCP = "yes";
    # TODO: pin the Hetzner-assigned /64 here like stronghold's network.nix
    # once the instance's address is known:
    #   address = ["2a01:4f9:...::1/64"];
    #
    # Routed IPv6 via the link-local gateway (Hetzner style)
    routes = [
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
    ];
    linkConfig.RequiredForOnline = "routable";
  };
}

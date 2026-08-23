{...}: {
  # systemd-networkd manages all interfaces
  networking.useDHCP = false;
  networking.useNetworkd = true;

  systemd.network.networks."10-end0" = {
    matchConfig.Name = "end0";
    networkConfig.DHCP = "yes";
  };
}

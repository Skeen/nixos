{
  ...
}: {

  networking = {
    enableIPv6 = true;

    interfaces.enp1s0.ipv6.addresses = [ {
      address = "2a01:4f9:c013:7d2b::1";
      prefixLength = 64;
    } ];

    defaultGateway6 = {
      address = "fe80::1";
      interface = "enp1s0";
    };
  };
}

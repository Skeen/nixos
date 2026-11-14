{ ... }: {
  swapDevices = [ {
    device = "/nix/swapfile";
    # Size in MiB
    size = 32 * 1024;
  } ];
}

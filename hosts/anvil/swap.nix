{ ... }: {
  swapDevices = [ {
    device = "/nix/swapfile";
    # Size in MiB
    size = 64 * 1024;
  } ];
}

# Hardware-specific tuning from nixos-hardware.
# https://github.com/NixOS/nixos-hardware
{nixos-hardware, ...}: {
  imports = [
    # There is no dedicated T580 module; the T480 is the same generation
    # (Kaby Lake R, Intel UHD 620, no dGPU) and imports the shared thinkpad
    # module (trackpoint, laptop commonalities) plus throttled.
    nixos-hardware.nixosModules.lenovo-thinkpad-t480
  ];
}

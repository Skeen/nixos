# Hardware-specific tuning from nixos-hardware.
# https://github.com/NixOS/nixos-hardware
{nixos-hardware, ...}: {
  imports = [
    # Board profile lacks amd-pstate and the GPU profile, so add those too.
    (nixos-hardware + "/msi/b350-tomahawk")
    nixos-hardware.nixosModules.common-cpu-amd-pstate
    nixos-hardware.nixosModules.common-gpu-amd
  ];
}

# Hardware-specific tuning from nixos-hardware.
# https://github.com/NixOS/nixos-hardware
{nixos-hardware, ...}: {
  imports = [
    nixos-hardware.nixosModules.common-cpu-amd
    nixos-hardware.nixosModules.common-cpu-amd-pstate
    # The nvidia GPU-generation modules are not exposed as `nixosModules`
    # attributes, so reference this one by path into the flake's source.
    (nixos-hardware + "/common/gpu/nvidia/blackwell")
    nixos-hardware.nixosModules.common-gpu-nvidia-sync
    nixos-hardware.nixosModules.common-pc
    nixos-hardware.nixosModules.common-pc-laptop
    nixos-hardware.nixosModules.common-pc-ssd
  ];

  # GPU
  # https://wiki.nixos.org/wiki/NVIDIA
  hardware.nvidia = {
    # Dynamic Boost shifts the power budget between the CPU and the dGPU under
    # load. Enables the nvidia-powerd daemon; check `systemctl status
    # nvidia-powerd` to confirm the laptop actually supports it.
    dynamicBoost.enable = true;
    prime = {
      amdgpuBusId = "PCI:6:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}

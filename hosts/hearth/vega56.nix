{ ... }: {
  # The memory clock (`pp_dpm_mclk`) has 4 discrete levels:
  # 0: 167Mhz
  # 1: 500Mhz
  # 2: 700Mhz
  # 3: 800Mhz
  #
  # Dropping from high frequency (500Mhz+) to 167Mhz sometimes result in signal drops.
  # Signal is restored almost immediately since the clock jumps back up to high
  # frequency, however these drops are very annoying, and we want to avoid them.
  #
  # The below installs udev rules turning the power management to manual and setting
  # the memory clock floor to level 1 (i.e. 500Mhz) meaning the memory clock is never
  # allowed to drop to the idle state thus avoiding signal drops.
  #
  # The trade-off here is slightly increased power consumption and heat generation,
  # however the card is plenty able to cool itself.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{power_dpm_force_performance_level}="manual"
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{pp_dpm_mclk}="1 2 3"
  '';
}

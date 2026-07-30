{...}: {
  # Tuxedo/Clevo laptop drivers; force the keyboard backlight and lightbar off.
  hardware.tuxedo-drivers.enable = true;
  services.udev.extraRules = ''
    SUBSYSTEM=="leds", KERNEL=="*kbd_backlight*", ATTR{brightness}="0"
    SUBSYSTEM=="leds", KERNEL=="*lightbar*", ATTR{brightness}="0"
  '';
}

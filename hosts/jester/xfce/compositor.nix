{...}: {
  # The Deck's panel is mounted sideways, so X rotates the whole screen (see
  # jovian.devices.steamdeck.enableXorgRotation), and the rotated picture
  # tears. The modesetting driver has no TearFree option to prevent that, but
  # the amdgpu one turns TearFree on for rotated outputs by default.
  # https://man.archlinux.org/man/amdgpu.4
  services.xserver.videoDrivers = ["amdgpu"];

  # Jovian rotates the output by its modesetting name, eDP-1, while amdgpu
  # calls the same output eDP.
  environment.etc."X11/xorg.conf.d/91-jester-rotation.conf".text = ''
    Section "Monitor"
      Identifier "eDP"
      Option     "Rotate" "right"
    EndSection
  '';
}

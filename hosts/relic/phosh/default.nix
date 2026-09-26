{...}: {
  # Phosh ("phone shell") is the GNOME-based Wayland shell for phones, running
  # on the phoc compositor. Despite the option living under `services.xserver`,
  # no X11 and no display manager is involved: the NixOS module runs
  # `phosh-session` as the system service `phosh.service` on tty1, as emil.
  # Phosh starts locked, so its lock screen is the "login".
  # https://phosh.mobi
  # https://gitlab.gnome.org/World/Phosh/phosh
  # https://github.com/mobile-nixos/mobile-nixos/tree/development/examples/phosh

  imports = [
    ./session.nix
    ./gsettings.nix
    ./keyboard.nix
    ./apps.nix
    ./trim.nix
  ];
}

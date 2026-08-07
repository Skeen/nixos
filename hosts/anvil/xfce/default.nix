{...}: {
  # TODO: Ensure that numpad is always enabled on login
  #       xfconf-query -c keyboards -p / -v -l
  # TODO: Declare Thunar configuration
  #       xfconf-query -c thunar -p / -v -l
  # TODO: Declare xfwm4:
  #       xfconf-query -c xfwm4 -p / -v -l
  # TODO: Declare xfce4-session:
  #       xfconf-query -c xfce4-session -p / -v -l
  #       "general/SaveOnExit" = false;

  imports = [
    ./panel.nix
    ./background.nix
    ./terminal.nix
    ./shortcuts.nix
  ];
}

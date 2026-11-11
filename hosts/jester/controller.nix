{...}: {
  # Without Steam, nothing disables the controller's lizard mode, its
  # firmware emulation of a keyboard and a mouse. What each control sends in
  # lizard mode, as seen with `libinput debug-events`:
  #
  #   Keyboard device ("Valve Software Steam Deck Controller", event4):
  #     D-pad                   KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT
  #     A                       KEY_ENTER
  #     B                       KEY_ESC
  #     View (left of screen)   KEY_TAB
  #     Menu (right of screen)  KEY_ESC, same as B
  #
  #   Mouse device ("Valve Software Steam Deck Controller", event5):
  #     Right trackpad          pointer movement
  #     Right trackpad click    BTN_LEFT
  #
  #   Nothing: Steam button, "..." button, left trackpad (click included),
  #   both sticks.
  #
  #   Not tested yet: X, Y, the bumpers, the triggers and the back grips.
  #
  # Steam handles the controller in the desktop session too, like on
  # SteamOS: it switches lizard mode off and maps every button through its
  # Desktop Layout (Steam > Settings > Controller), with Steam+X for its
  # on-screen keyboard. Start it minimized to the tray with the session.
  # https://github.com/Jovian-Experiments/Jovian-NixOS/issues/519
  home-manager.users.emil = {pkgs, ...}: {
    xdg.autostart = {
      enable = true;
      entries = [
        "${pkgs.makeDesktopItem {
          name = "steam-silent";
          desktopName = "Steam";
          exec = "steam -silent";
          noDisplay = true;
        }}/share/applications/steam-silent.desktop"
      ];
    };
  };
}

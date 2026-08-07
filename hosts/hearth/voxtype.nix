{
  pkgs,
  nixpkgs-unstable,
  home-manager-unstable,
  ...
}: let
  # Voxtype is not in nixpkgs 25.05 yet.
  # TODO: Remove in NixOS 26.11
  voxtype = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.voxtype-onnx;
in {
  # Voice-to-text with local, offline transcription.
  # https://voxtype.io
  #
  # A user daemon records audio, transcribes it, and types the result at the
  # cursor.

  # Transcribed text is typed by dotool, which synthesizes key events through
  # /dev/uinput.
  hardware.uinput.enable = true;
  users.users.emil.extraGroups = ["uinput"];

  home-manager.users.emil = {
    # The voxtype module has not been released yet.
    # TODO: Remove in home-manager 26.11
    imports = [
      "${home-manager-unstable}/modules/services/voxtype.nix"
    ];

    services.voxtype = {
      enable = true;
      package = voxtype;
      # Downloaded on first start to ~/.local/share/voxtype
      loadModels = [
        "parakeet-tdt-0.6b-v2"
      ];
      settings = {
        engine = "parakeet";
        parakeet = {
          model = "parakeet-tdt-0.6b-v2";
          # Don't keep the ~2.4G model resident between dictations. Loading
          # starts when recording does, so it overlaps whatever is being said.
          on_demand_loading = true;
        };

        # Recording is toggled by an xfce shortcut, see: xfce/shortcuts.nix.
        hotkey.enabled = false;

        # Effectively no limit (1 day), deliberately.
        #
        # Reaching the limit does not discard the recording, rather it
        # transcribes everything into the currently active window.
        #
        # We want to avoid sending key-presses into windows unintentionally, so
        # we set the limit absurdly high.
        #
        # Cannot be zero, as that times out instantly.
        audio.max_duration_secs = 86400;

        output = {
          # Default driver is wtype/eitype (wayland only), we use dotool on X11
          driver_order = ["dotool"];

          # Never overwrite the clipboard. If dotool fails, just fail.
          fallback_to_clipboard = false;

          # dotool synthesizes keycodes rather than characters, so it needs the
          # layout to hit the right keys
          dotool_xkb_layout = "dk";

          notification.on_transcription = false;
        };

        # Strip "uh", "um" and similar disfluencies from what we said.
        text.filter_filler_words = true;

        # The on-screen display needs wayland. We have a panel indicator
        # instead, see: xfce/panel.nix.
        osd.enabled = false;
      };
    };
  };
}

{pkgs, ...}: let
  # TODO(satchel): Internal laptop panel fingerprint, from `autorandr --fingerprint`
  # on the target. The T580 panel is connected over eDP-1 (Intel i915 naming).
  edp_fingerprint = "TODO";
in {
  # AutoRandr is a smart wrapper around xrandr for handling display configuration
  services.autorandr = {
    enable = true;

    profiles = {
      # Fallback when no externals are attached: laptop panel only.
      # Matches because eDP-1 is then the sole fingerprinted output.
      "default" = {
        fingerprint = {
          # TODO(satchel): Confirm the output name with `xrandr` on the target
          "eDP-1" = edp_fingerprint;
        };
        config = {
          "eDP-1" = {
            enable = true;
            primary = true;
            position = "0x0";
            # TODO(satchel): Confirm the native mode with `xrandr` on the target
            # (1920x1080 or 3840x2160 depending on the panel option)
            mode = "1920x1080";
            rate = "60.00";
          };
        };
      };
    };
  };

  environment.systemPackages = [pkgs.autorandr];
}

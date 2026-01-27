{pkgs, ...}: {
  # 1. Force the mode creation on startup
  services.xserver.displayManager.sessionCommands = ''
    # Create a 5120x1440 120Hz mode and add it to DP-3, this is at the very limit of DisplayPort 1.4 without DSC
    (Display Stream Compression), as this requires ~23.2Gbps which is close to the maximum bandwidth of ~25.9Gbps.
    # This modeline has been calculated with: `nix-shell -p libxcvt --run "cvt -r 5120 1440 120"`
    ${pkgs.xorg.xrandr}/bin/xrandr --newmode "5120x1440_120" 965.50  5120 5168 5200 5280  1440 1443 1453 1525 +hsync -vsync
    ${pkgs.xorg.xrandr}/bin/xrandr --addmode DP-3 "5120x1440_120"
  '';

  # AutoRandr is a smart wrapper around xrandr for handling display configuration
  services.autorandr = {
    enable = true;

    profiles = {
      "default" = {
        # Fingerprints produced using `autorandr --fingerprint`
        # NOTE: This should be aligned with xfce/background.nix
        fingerprint = {
          "DP-3" = "00ffffffffffff004c2dae74374653301f230104b57722783b1245ac5248a72710505425cf00714f810081c08180a9c0b3009500d1c01a6800a0f0381f4030203a00a9504100001a000000fd0c60f06666c2010a202020202020000000fc004f64797373657920473935430a000000ff00484e54593730303632350a2020024202032ff0431004032309070783010000e305c0006d1a0000020f60f000048b197321e60605018b7302e5018b8490791a6800a0f0381f4030203a00a9504100001a565e00a0a0a0295030203500a9504100001a2dd68078703829401c203a00a9504100001a0000000000000000000000000000000000000000000000000000c570127903000301509cf50288ff133f017f801f009f052e000200090033b70008ff139f002f801f009f052800020009007c910108ff093f017f801f009f052e00020009000daf0108ff0e17016b801f0037042300020009000000000000000000000000000000000000000000000000000000000000000000000000000000b890";
          "HDMI-1" = "00ffffffffffff0005e3602024b10300341b0103802c18782aeed1a555489b26125054bfef00d1c0b30095008180814081c001010101023a801871382d40582c4500b3ef1000001e000000fd00324c1e5311000a202020202020000000fc003230363057330a202020202020000000ff00474345484348413234313935360088";
          "HDMI-2" = "00ffffffffffff0005e3602075910300271b0103802c18782aeed1a555489b26125054bfef00d1c0b30095008180814081c001010101023a801871382d40582c4500b3ef1000001e000000fd00324c1e5311000a202020202020000000fc003230363057330a202020202020000000ff00474345483948413233333834350070";
          "HDMI-3" = "00ffffffffffff0005e3602072910300271b0103802c18782aeed1a555489b26125054bfef00d1c0b30095008180814081c001010101023a801871382d40582c4500b3ef1000001e000000fd00324c1e5311000a202020202020000000fc003230363057330a202020202020000000ff00474345483948413233333834320076";
        };
        config = {
          # Top
          # ---
          # Left
          "HDMI-1" = {
            enable = true;
            position = "0x0";
            mode = "1920x1080";
            rate = "60.00";
          };
          # Middle
          "HDMI-3" = {
            enable = true;
            position = "1920x0";
            mode = "1920x1080";
            rate = "60.00";
          };
          # Right
          "HDMI-2" = {
            enable = true;
            position = "3840x0";
            mode = "1920x1080";
            rate = "60.00";
          };

          # Bottom
          # ------
          # Ultrawide
          "DP-3" = {
            enable = true;
            primary = true;
            position = "640x1080";
            mode = "5120x1440_120";
            rate = "120.00";
          };
        };
        hooks.postswitch = {
          # Force 'opRGB' Colorspace to override the driver's default 'Limited Range' (TV Mode) selection.
          "fix-g9-colors" = "${pkgs.xorg.xrandr}/bin/xrandr --output DP-3 --set 'max bpc' 8 --set 'Colorspace' 'opRGB'";
        };
      };
    };
  };

  environment.systemPackages = [ pkgs.autorandr ];
}

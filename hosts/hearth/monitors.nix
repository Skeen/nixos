{pkgs, ...}: {
  # AutoRandr is a smart wrapper around xrandr for handling display configuration
  services.autorandr = {
    enable = true;

    profiles = {
      "default" = {
        # Fingerprints produced using `autorandr --fingerprint`
        fingerprint = {
          #"DP-1" = "...";
          "DP-2" = "00ffffffffffff0005e36020d9790300241b0103802c18782aeed1a555489b26125054bfef00d1c0b30095008180814081c001010101023a801871382d40582c4500b3ef1000001e000000fd00324c1e5311000a202020202020000000fc003230363057330a202020202020000000ff0047434548394841323237383031002c";
          "DP-3" = "00ffffffffffff0005e36020c28a0300261b0103802c18782aeed1a555489b26125054bfef00d1c0b30095008180814081c001010101023a801871382d40582c4500b3ef1000001e000000fd00324c1e5311000a202020202020000000fc003230363057330a202020202020000000ff00474345483948413233323133300039";
          "HDMI-1" = "00ffffffffffff0005e3602075910300271b0103802c18782aeed1a555489b26125054bfef00d1c0b30095008180814081c001010101023a801871382d40582c4500b3ef1000001e000000fd00324c1e5311000a202020202020000000fc003230363057330a202020202020000000ff00474345483948413233333834350070";
          "HDMI-2" = "00ffffffffffff0005e3602072910300271b0103802c18782aeed1a555489b26125054bfef00d1c0b30095008180814081c001010101023a801871382d40582c4500b3ef1000001e000000fd00324c1e5311000a202020202020000000fc003230363057330a202020202020000000ff00474345483948413233333834320076";
          "HDMI-3" = "00ffffffffffff0005e36020ff860300261b0103802c18782aeed1a555489b26125054bfef00d1c0b30095008180814081c001010101023a801871382d40582c4500b3ef1000001e000000fd00324c1e5311000a202020202020000000fc003230363057330a202020202020000000ff004743454839484132333131363700f7";
        };
        config = {
          # Top
          # ---
          # Left
          "DP-1" = {
            enable = false;
            position = "0x0";
            mode = "1920x1080";
          };
          # Middle
          "HDMI-2" = {
            enable = true;
            position = "1920x0";
            mode = "1920x1080";
          };
          # Right
          "DP-2" = {
            enable = true;
            position = "3840x0";
            mode = "1920x1080";
          };

          # Bottom
          # ------
          # Left
          "HDMI-1" = {
            enable = true;
            position = "0x1080";
            mode = "1920x1080";
          };
          # Middle
          "DP-3" = {
            enable = true;
            primary = true;
            position = "1920x1080";
            mode = "1920x1080";
          };
          # Right
          "HDMI-3" = {
            enable = true;
            position = "3840x1080";
            mode = "1920x1080";
          };
        };
      };
    };
  };

  environment.systemPackages = [ pkgs.autorandr ];
}

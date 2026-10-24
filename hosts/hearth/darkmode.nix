{ ... }: {
  home-manager.users.emil = { config, pkgs, lib, ... }: {

    home.packages = with pkgs; [
      gnome-themes-extra
      adwaita-icon-theme
    ];

    # 2. Force GTK to use Dark Mode
    gtk = {
      enable = true;
      
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };
      
      # The dark icons are inside the main package
      iconTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };

      # This puts 'gtk-application-prefer-dark-theme=1' in ~/.config/gtk-3.0/settings.ini
      gtk3.extraConfig = {
        Settings = ''
          gtk-application-prefer-dark-theme=1
        '';
      };
      # Home Manager 26.05 no longer applies gtk.theme to GTK4 by default
      gtk4.theme = config.gtk.theme;
      # This puts 'gtk-application-prefer-dark-theme=1' in ~/.config/gtk-4.0/settings.ini
      gtk4.extraConfig = {
        Settings = ''
          gtk-application-prefer-dark-theme=1
        '';
      };
    };

    # 3. Force "Modern" Apps (GTK4/LibAdwaita) to Dark Mode
    # Without this, apps like Chrome or Nautilus might stay white.
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };

    # 4. Force Xfce Specifics (The "Panel & Window" Way)
    xfconf.settings = {
      xsettings = {
        "Net/ThemeName" = "Adwaita-dark";      # Window content
        "Net/IconThemeName" = "Adwaita";       # Icons
      };
      xfwm4 = {
        "general/theme" = "Adwaita-dark";      # Window borders (Title bars)
      };
    };
  };
}

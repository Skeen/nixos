{ ... }: {
  # Kill the biggest process before memory runs out and the desktop freezes.
  services.earlyoom = {
    enable = true;
    # Act at 5% free RAM (~3 GiB) and 10% free swap, both must be low.
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true;
    extraArgs = [
      # Firefox tab processes are cheap to lose
      "--prefer" "^(Isolated Web Co|Web Content)$"
      # Keep the session and remote access alive
      "--avoid" "^(Xorg|lightdm|xfce4-session|xfwm4|xfce4-panel|sshd|systemd)$"
    ];
  };
}

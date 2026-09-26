{impermanence, ...}: {
  # Impermanence in NixOS is where the root directory isn't permanent, but gets
  # wiped every reboot (such as by mounting it as tmpfs). Such a setup is
  # possible because NixOS only needs /boot and /nix in order to boot, all
  # other system files are simply links to files in /nix.

  # The impermanence module bind-mounts persistent files and directories,
  # stored in /nix/persist, into the tmpfs root partition on startup. For
  # example: /nix/persist/etc/machine-id is mounted to /etc/machine-id.
  # https://github.com/nix-community/impermanence
  # https://wiki.nixos.org/wiki/Impermanence
  # https://elis.nu/blog/2020/05/nixos-tmpfs-as-root/

  imports = [
    impermanence.nixosModules.impermanence
  ];

  # Each module will configure the paths they need persisted. Here we define
  # some general system paths that don't really fit anywhere else.
  #
  # /var/lib/nixos and /var/log are persisted in ./hardware.nix instead: the
  # Mobile NixOS stage-1 does not run the early bind mounts impermanence
  # relies on for them.
  environment.persistence."/nix/persist" = {
    hideMounts = true;
    directories = [
      # Save the last run time of persistent timers so systemd knows if they were missed
      {
        directory = "/var/lib/systemd/timers";
        user = "root";
        group = "root";
        mode = "0755";
      }
      # /var/tmp is meant for temporary files that are preserved across
      # reboots. Some programs might store files too big for in-memory /tmp
      # there. Files are automatically cleaned by systemd.
      {
        directory = "/var/tmp";
        user = "root";
        group = "root";
        mode = "1777";
      }
      # The OnePlus 6 RTC is read-only (the mainline pm8998 RTC has neither
      # allow-set-time nor an nvmem offset cell), so every boot starts at
      # systemd's build date. systemd-timesyncd moves the clock forward to
      # the mtime of the clock file kept here, which it refreshes every
      # minute, so a reboot away from Wi-Fi resumes close to the real time.
      {
        directory = "/var/lib/systemd/timesync";
        user = "systemd-timesync";
        group = "systemd-timesync";
        mode = "0755";
      }
      # Screen brightness and rfkill (e.g. Bluetooth off) state, restored by
      # systemd-backlight and systemd-rfkill. Without them the OLED panel
      # starts at full brightness on every boot.
      {
        directory = "/var/lib/systemd/backlight";
        user = "root";
        group = "root";
        mode = "0755";
      }
      {
        directory = "/var/lib/systemd/rfkill";
        user = "root";
        group = "root";
        mode = "0755";
      }
      # Kernel crash logs (ramoops), archived from /sys/fs/pstore on the next
      # boot by systemd-pstore.
      {
        directory = "/var/lib/systemd/pstore";
        user = "root";
        group = "root";
        mode = "0755";
      }
      # The entire home directory: dconf settings, keyrings, call and message
      # history, browser profile. Declared as a system directory, because
      # `users.emil.directories = ["/"]` (as on satchel) fails to evaluate on
      # nixpkgs-unstable ("cannot create list of size -1").
      {
        directory = "/home/emil";
        user = "emil";
        group = "users";
        mode = "0700";
      }
      # Wi-Fi networks and the mobile data APN added from the Settings app
      {
        directory = "/etc/NetworkManager/system-connections";
        user = "root";
        group = "root";
        mode = "0700";
      }
      {
        directory = "/var/lib/NetworkManager";
        user = "root";
        group = "root";
        mode = "0755";
      }
      # Bluetooth pairings
      {
        directory = "/var/lib/bluetooth";
        user = "root";
        group = "root";
        mode = "0700";
      }
    ];
    files = [
      "/etc/machine-id" # needed for /var/log
    ];
  };
}

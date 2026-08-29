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
  environment.persistence."/nix/persist" = {
    hideMounts = true;
    directories = [
      # The uid and gid maps for entities without a static id is saved in
      # /var/lib/nixos. Persist to ensure they aren't changed between reboots.
      {
        directory = "/var/lib/nixos";
        user = "root";
        group = "root";
        mode = "0755";
      }
      # Save the last run time of persistent timers so systemd knows if they were missed
      {
        directory = "/var/lib/systemd/timers";
        user = "root";
        group = "root";
        mode = "0755";
      }
      {
        directory = "/var/log";
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
    ];
    files = [
      "/etc/machine-id" # needed for /var/log
    ];
    users.emil = {
      directories = [
        "/" # entire home directory (TODO?)
      ];
    };
  };
}

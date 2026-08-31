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
      # Kubernetes control plane state: etcd (the source of truth for the
      # cluster), certificates issued by easyCerts, and the pki secrets.
      {
        directory = "/var/lib/etcd";
        user = "etcd";
        group = "etcd";
        mode = "0700";
      }
      {
        directory = "/var/lib/kubernetes";
        user = "kubernetes";
        group = "kubernetes";
        mode = "0755";
      }
      # kubelet root dir: pod identity/plumbing that must survive reboot for
      # the node not to fight itself (isini, pod reports, plugin state).
      {
        directory = "/var/lib/kubelet";
        user = "root";
        group = "root";
        mode = "0755";
      }
      # containerd state: images (incl. the sandbox images), layer store.
      {
        directory = "/var/lib/containerd";
        user = "root";
        group = "root";
        mode = "0755";
      }
      # Flannel's subnet leases file - regenerated via the apiserver if lost.
      {
        directory = "/var/lib/flannel";
        user = "root";
        group = "root";
        mode = "0755";
      }
    ];
    files = [
      "/etc/machine-id" # needed for /var/log
    ];
  };

  # These files are just cache which can be removed whenever
  environment.persistence."/nix/cache" = {
    hideMounts = true;
    directories = [
      {
        directory = "/root/.cache";
        user = "root";
        group = "root";
        mode = "0700";
      }
    ];
    files = [
      "/root/.nix-channels"
    ];
  };
}

# What makes clank's NixOS system (its container modules, and those of
# ../../../modules/base/clank/modules.nix) the system of an agent's sandbox
# (../agents.nix): booted in a Kata VM rather than a podman container, with
# the sandbox's volume at /disk and /persist, and opencode as a server for the
# Redmine operator.
{
  lib,
  pkgs,
  ...
}: {
  # clank's mounts and podman's storage expect directories on /disk and
  # /persist, which a new sandbox's volume lacks.
  systemd.services.clank-directories = {
    unitConfig.DefaultDependencies = false;
    before = ["local-fs-pre.target"];
    wantedBy = ["local-fs-pre.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /disk/var/tmp /disk/graphroot /persist/imagestore \
        /persist/root/.cache /persist/root/.local/share/fish \
        /persist/root/.local/share/opencode /persist/root/.local/state/opencode
      chmod 1777 /disk/var/tmp
    '';
  };

  # Kubernetes provides /etc/resolv.conf, with the cluster's DNS and search
  # domains (as for clank-proxy); resolvconf would write over it with neither.
  networking.resolvconf.enable = lib.mkForce false;

  # A pod has no console to log in on (clank powers off when that login
  # ends), nor a directory of the host for Claude Code to trust.
  systemd.services.console-getty.enable = lib.mkForce false;
  systemd.services.claude-auto-trust.enable = lib.mkForce false;

  # podman's storage is on virtio-fs, which the kernel's overlay cannot write
  # to, so it goes through fuse-overlayfs. FUSE is in the VM's kernel, but not
  # among the devices of the container.
  virtualisation.containers.storage.rootful.settings.storage.options.overlay.mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs";
  systemd.tmpfiles.rules = ["c /dev/fuse 0666 root root - 10:229"];

  programs.git.config.user = {
    name = "AI Bot";
    email = "ai@magenta.dk";
  };

  # opencode as a server, in the environment of a login shell of clank, with
  # the password the operator made up (mounted from the Secret
  # `agent-server`)
  systemd.services.opencode-serve = {
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "home-manager-root.service"];
    wants = ["network-online.target" "home-manager-root.service"];
    serviceConfig = {
      WorkingDirectory = "/workspace";
      Restart = "always";
    };
    environment.HOME = "/root";
    script = ''
      export OPENCODE_SERVER_PASSWORD="$(cat /secrets/agent-server/password)"
      exec ${pkgs.bashInteractive}/bin/bash -l -c 'exec opencode serve --hostname 0.0.0.0 --port 4096 --print-logs'
    '';
  };

  home-manager.users.root.programs.opencode.settings = {
    model = "greenpt/glm-5.3";
    instructions = ["${./AGENTS.md}"];
    # On top of clank's, which allow everything: nobody is there to answer a
    # question, so the agent asks in its reply instead.
    permissions = lib.mkAfter [
      {
        action = "question";
        resource = "*";
        effect = "deny";
      }
    ];
    # Nor is anybody there to undo changes or share sessions
    share = "disabled";
    snapshots = false;
  };
}

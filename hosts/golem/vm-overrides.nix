# Overrides applied on top of golem when running it as a local test VM
# (.#golemVm): a known root password file path (so serial-console login works,
# unlike the agenix-encrypted hash we cannot decrypt without the identity
# key), and VM-appropriate QEMU settings.
{
  lib,
  ...
}: {
  # Put the password where we control the content: the VM's persistent disk
  # (nixos-rebuild build-vm creates it fresh; we write the file via a
  # systemd oneshot below, hashed with the fixed test password).
  users.users.root.hashedPasswordFile = lib.mkForce null;
  users.users.root.password = "golem";
  users.users.installuser.password = "golem";

  users.users.installuser = {
    isNormalUser = true;
    description = "VM test user";
    useDefaultShell = true;
  };

  systemd.services.vm-root-password = {
    description = "Write the test root password hash";
    wantedBy = ["multi-user.target"];
    before = ["getty.target"];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      echo root:golem | chpasswd
    '';
  };

  virtualisation.vmVariant = {
    # More resources for etcd + containerd.
    virtualisation.memorySize = 4096;
    virtualisation.cores = 4;
    virtualisation.diskSize = 16384;
    # Forward SSH from localhost:2222 into the VM for scripted testing.
    virtualisation.forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
    services.openssh.settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = lib.mkForce true;
    };
    services.getty.autologinUser = lib.mkOverride 90 "root";
  };
}

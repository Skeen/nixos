{...}: {
  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      # Disable root login
      PermitRootLogin = "no";
      # Disable password login
      PasswordAuthentication = false;
      # Disable interactive login
      KbdInteractiveAuthentication = false;
    };
  };

  # Configure which ssh-keys can log in
  users.users.emil = {
    openssh.authorizedKeys.keys = [
      # TODO: Remove this key once hearth has superseeded morphine
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUcHrd+lfdEU/HIhhQ8XKc3TSeum4aL/n4LoAWmBFDLX9J7dbi7Wo2dZIm1eREoWbMilL7vp+aq8bT+IeMcRREoJ+XRIXB7F/jFO55NtjRpACKaaFXSvH9c1RcMuW1XS3ZvK944jKTsas/bObqU1ICo/LgPchwxhk6lb1JcblIIkS18zOvm/i7vb1BK63uBGy6GEwn8d+QFp9NgKbsKb3osG3mQ7VokYEt8WVyssPcahyZe+LP49LJpGOtbCewCGHnk6oAXoOHcAJknJaeQoHAZrl8NEa8JBrOkR6p/+nJSb/HoAfnkReMXNTjlzVitVNC+lkkr9CefiGtufm68qIr skeen@morphine"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKFg8JIuWxmbMWzZRk+VbHNDLZRMi4dAVTOvAfDsba3G emil@anvil"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfdJuJUqcgLKxliUIQEz5l8rkVabTBqVDundCW1xv33 emil@hearth"
    ];
  };

  # Persist host-key across reboots to avoid 'REMOTE HOST IDENTIFICATION HAS CHANGED!'
  environment.persistence."/nix/persist" = {
    files = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
}

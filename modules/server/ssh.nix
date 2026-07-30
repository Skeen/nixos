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

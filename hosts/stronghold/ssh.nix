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
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDUcHrd+lfdEU/HIhhQ8XKc3TSeum4aL/n4LoAWmBFDLX9J7dbi7Wo2dZIm1eREoWbMilL7vp+aq8bT+IeMcRREoJ+XRIXB7F/jFO55NtjRpACKaaFXSvH9c1RcMuW1XS3ZvK944jKTsas/bObqU1ICo/LgPchwxhk6lb1JcblIIkS18zOvm/i7vb1BK63uBGy6GEwn8d+QFp9NgKbsKb3osG3mQ7VokYEt8WVyssPcahyZe+LP49LJpGOtbCewCGHnk6oAXoOHcAJknJaeQoHAZrl8NEa8JBrOkR6p/+nJSb/HoAfnkReMXNTjlzVitVNC+lkkr9CefiGtufm68qIr skeen@morphine"
    ];
  };
}

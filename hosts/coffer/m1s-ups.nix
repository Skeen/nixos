{ m1s-ups, ... }: {
  # Enable M1S UPS service
  imports = [ m1s-ups.nixosModules.default ];
  services.m1s-ups.enable = true;
}

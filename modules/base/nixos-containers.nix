{...}: {
  # We assume that any important files in NixOS containers are mounted out and persisted
  # on the host itself instead of relying on persistence within the container itself.
  # Thus we assume that all NixOS containers are just cache files.
  #
  # We expect containers to clean up after themselves and try to keep themselves lean.
  # Preferably by the containers themselves using tmpfs on root, so we do not actually
  # cleanup any files that they may make automatically.
  environment.persistence."/nix/cache" = {
    hideMounts = true;
    directories = [
      {
        directory = "/var/lib/nixos-containers";
        user = "root";
        group = "root";
        mode = "0755";
      }
    ];
  };
}

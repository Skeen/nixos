{...}: {
  # These files are just cache which can be removed whenever
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

  #systemd.tmpfiles.rules = [
  #  "e     /nix/cache/var/lib/nixos-containers   - - - 30d -"
  #];
}

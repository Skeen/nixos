{
  clank,
  config,
  pkgs,
  secrets,
  ...
}: {
  environment.systemPackages = [
    (clank.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      extraModules = import ./clank/modules.nix {inherit clank;};
    })
  ];

  # Token values for the public clank Caddyfile template, as KEY=value pairs.
  age.secrets.clank-caddyfile-env = {
    file = "${secrets}/secrets/clank-caddyfile.env.age";
    mode = "400";
    owner = config.users.users.emil.name;
    group = config.users.users.emil.group;
  };

  home-manager.users.emil = {
    lib,
    osConfig,
    ...
  }: {
    # Render template + agenix values into the Caddyfile clank mounts. clank
    # does not pass env into the proxy, so we substitute `{$VAR}` ourselves.
    home.activation.clankCaddyfile = let
      template = ./clank/Caddyfile;
      envFile = osConfig.age.secrets.clank-caddyfile-env.path;
      render = pkgs.writeShellScript "render-clank-caddyfile" ''
        set -a
        . "$1"
        set +a
        ${pkgs.perl}/bin/perl -pe 's/\{\$([A-Z0-9_]+)\}/$ENV{$1} \/\/ ""/ge' "$2"
      '';
    in
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        install -D -m600 /dev/null "$HOME/.config/clank/Caddyfile"
        ${render} "${envFile}" "${template}" > "$HOME/.config/clank/Caddyfile"
        chmod 600 "$HOME/.config/clank/Caddyfile"
      '';
  };
}

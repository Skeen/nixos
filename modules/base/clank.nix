{
  clank,
  config,
  pkgs,
  secrets,
  ...
}: {
  environment.systemPackages = [
    (clank.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      extraModules = [
        # Magenta modules: gitlab, grafana-logs and kagi. They route through
        # the credentials-injecting Caddy proxy at clank-proxy:<port>.
        ({...}: {
          imports = [
            "${clank}/magenta/modules/gitlab.nix"
            "${clank}/magenta/modules/grafana-logs.nix"
            "${clank}/magenta/modules/kagi.nix"
          ];
        })
        ({pkgs, ...}: let
          # https://github.com/berget-ai/opencode-berget-auth
          # Adds `/connect` for Berget auth. Referenced by store path so
          # OpenCode loads it locally instead of fetching from npm.
          berget-auth = pkgs.fetchzip {
            name = "opencode-berget-auth-1.0.24";
            url = "https://registry.npmjs.org/@bergetai/opencode-auth/-/opencode-auth-1.0.24.tgz";
            hash = "sha256-4wt5VA5RiqWWW7030apXEoHQNWIj+aCXUXDfBVozf98=";
          };
        in {
          home-manager.users.root = {
            programs.opencode = {
              # Disable mouse capture so the host terminal's native selection
              # is preserved. The TUI's own copy path (xclip/OSC 52) cannot
              # reach the host clipboard from inside the container anyway.
              tui.mouse = false;
              settings = {
                "$schema" = "https://opencode.ai/config.json";
                plugin = ["${berget-auth}"];
                # BergetAI can be slow; give requests plenty of headroom so
                # opencode does not abort with "The operation timed out."
                provider.berget.options = {
                  # Overall cap per request. Raised from 10 min after Kimi-K3
                  # repeatedly stalled past it with no streamed output.
                  timeout = 1800000;
                  headerTimeout = 120000;
                  chunkTimeout = 300000;
                };
                # GreenPT routes through the credentials-injecting proxy like
                # the Magenta tools, so the sandbox only sees the dummy key.
                provider.greenpt.options = {
                  apiKey = "dummy";
                  baseURL = "http://clank-proxy:1655/v1";
                };
              };
            };
          };
        })
      ];
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

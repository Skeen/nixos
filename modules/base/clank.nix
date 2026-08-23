{
  clank,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    (clank.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      extraModules = [
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
              };
            };
          };
        })
      ];
    })
  ];
}

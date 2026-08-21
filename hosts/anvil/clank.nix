{
  clank,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    (clank.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      extraModules = [
        ({...}: {
          home-manager.users.root = {
            programs.opencode = {
              settings = {
                "$schema" = "https://opencode.ai/config.json";
                # https://github.com/berget-ai/opencode-berget-auth
                # Adds `/connect` for Berget authentication.
                plugin = ["@bergetai/opencode-auth@1.0.24"];
              };
            };
          };
        })
      ];
    })
  ];
}

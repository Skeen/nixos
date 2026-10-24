{
  pkgs,
  nixpkgs-2505,
  ...
}: let
  # lunarvim was removed in nixpkgs 26.05 as it is abandoned upstream. Keep
  # the last packaged version from nixpkgs 25.05.
  pkgs2505 = nixpkgs-2505.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in {
  environment.systemPackages = with pkgs; [
    (pkgs2505.lunarvim.override {
      viAlias = true;
      vimAlias = true;
      nvimAlias = true;
    })
  ];
  environment.variables.EDITOR = "lvim";

  # These files are just cache which can be removed whenever
  environment.persistence."/nix/cache" = {
    hideMounts = true;
    users.emil = {
      directories = [
        ".cache/lvim/"
        ".local/share/lvim"
        ".local/state/lvim"
        # TODO: These do not really belong here
        ".npm/_cacache"
        ".npm/_logs"
        ".cargo/registry"
        ".cargo/git"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "e     /nix/cache/home/emil/.cache/lvim - - - 14d -"
    "e     /nix/cache/home/emil/.local/share/lvim - - - 14d -"
    "e     /nix/cache/home/emil/.local/state/lvim - - - 14d -"
    "e     /nix/cache/home/emil/.npm/_cacache - - - 14d -"
    "e     /nix/cache/home/emil/.npm/_logs - - - 14d -"
    "e     /nix/cache/home/emil/.cargo/registry - - - 14d -"
    "e     /nix/cache/home/emil/.cargo/git - - - 14d -"
  ];
}

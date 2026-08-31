# LunarVim-compatible NixVim editor (see ../../modules/editor) plus the
# impermanence cache directories the old LunarVim setup used.
{pkgs, ...}: {
  imports = [
    ../../modules/editor
  ];

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

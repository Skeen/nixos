# NixOS module for lvim-nixvim.
#
# Replaces the upstream-abandoned `lunarvim` package with a NixVim build that
# reproduces LunarVim 1.4's default behaviour (see ../modules/nixvim-module.nix).
#
# The old LunarVim package shipped `lvim` (with vi/vim/nvim aliases) and ran
# nvim with NVIM_APPNAME=lvim, so user data lived in ~/.config/lvim,
# ~/.local/share/lvim and ~/.cache/lvim. The wrapper below preserves that: the
# NixVim binary is exposed as both `lvim` and `nvim`, with `vi`/`vim` aliases.
{
  config,
  lib,
  pkgs,
  # Flake inputs are passed as `specialArgs = inputs;` and are available
  # under their own names.
  nixvim,
  ...
}: let
  cfg = config.programs.lvim;

  # The NixVim configuration matching LunarVim's defaults
  nixvimPackage = nixvim.legacyPackages.${pkgs.system}.makeNixvimWithModule {
    module = ./nixvim-module.nix;
  };

  # Wrap so all invocations (including the vi/vim/lvim aliases) use
  # NVIM_APPNAME=lvim, like the old LunarVim package did.
  lvim = pkgs.runCommand "lvim" {} ''
    mkdir -p $out/bin
    for prog in nvim nvim-python3 nvim-ruby; do
      if [ -e ${nixvimPackage}/bin/$prog ]; then
        # resolve the -u init.lua path from the wrapped binary at build time
        INITLUA=$(sed -n "s|.* -u \(/nix/store/[^ ]*init\.lua\) .*|\1|p" ${nixvimPackage}/bin/nvim | head -1)
        printf '#!/bin/sh\nexport NVIM_APPNAME="lvim"\nexport MYVIMRC="%s"\nexec ${nixvimPackage}/bin/%s "$@"\n' "$INITLUA" "$prog" > $out/bin/$prog
        chmod +x $out/bin/$prog
      fi
    done
    ln -s nvim $out/bin/lvim
    ln -s nvim $out/bin/vi
    ln -s nvim $out/bin/vim
  '';
in {
  options.programs.lvim = {
    enable = lib.mkEnableOption "the LunarVim-compatible NixVim editor";

    editor = lib.mkOption {
      type = lib.types.str;
      default = "lvim";
      example = "nvim";
      description = ''
        Command which the EDITOR environment variable is set to.
      '';
    };
  };

  config = {
    programs.lvim.enable = true;

    environment.systemPackages = lib.mkIf cfg.enable [
      lvim
      # Tooling the LunarVim wrapper put on PATH for nvim runtime helpers
      # (treesitter compilation, illuminate's cc check)
      pkgs.gcc
      # xclip is needed for clipboard control from the editor (i.e. space+y)
      pkgs.xclip
    ];

    environment.variables.EDITOR = cfg.editor;
  };
}

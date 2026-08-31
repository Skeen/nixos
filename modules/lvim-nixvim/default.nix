# lvim-nixvim — a NixVim distribution that reproduces LunarVim 1.4's default
# behaviour as closely as possible. For anyone migrating away from LunarVim
# (upstream-abandoned) without changing muscle memory.
#
# See docs/EQUIVALENCE.md for the behavioural contract and tests/ for the
# keystroke-level equivalence harness that proves it.
{
  inputs,
  ...
}: {
  # The Nixvim configuration module (module argument: pkgs)
  nixvimModule = ./nixvim-module.nix;

  # Build the LunarVim-compatible editor for a system
  buildEditor = {
    system,
    nixpkgs,
    nixvim,
  }: let
    pkgs = nixpkgs.legacyPackages.${system};
    nixvimPackage = nixvim.legacyPackages.${system}.makeNixvimWithModule {
      module = ./modules/nixvim-module.nix;
    };
  in
    pkgs.runCommand "lvim" {} ''
      mkdir -p $out/bin
      for prog in nvim nvim-python3 nvim-ruby; do
        if [ -e ${nixvimPackage}/bin/$prog ]; then
          # MYVIMRC is unset by nvim at startup, so resolve it from the
          # wrapper here (see userCommands.LvimReload)
          INITLUA=$(sed -n "s|.* -u \(/nix/store/[^ ]*init\.lua\) .*|\1|p" ${nixvimPackage}/bin/nvim | head -1)
          printf '#!/bin/sh\nexport NVIM_APPNAME="lvim"\nexport MYVIMRC="%s"\nexec ${nixvimPackage}/bin/%s "$@"\n' "$INITLUA" "$prog" > $out/bin/$prog
          chmod +x $out/bin/$prog
        fi
      done
      ln -s nvim $out/bin/lvim
      ln -s nvim $out/bin/vi
      ln -s nvim $out/bin/vim
    '';

  # NixOS module entry: programs.lvim { enable, editor }
  nixosModule = ./nixos-module.nix;
}

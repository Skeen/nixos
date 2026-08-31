# NixOS glue for the lvim-nixvim editor.
#
# The lvim-nixvim editor lives in its own repository at ../lvim-nixvim
# (usable standalone by anyone migrating from LunarVim); this thin NixOS
# wrapper wires it into the system config.
{
  ...
}: {
  imports = [
    ../lvim-nixvim/nixos-module.nix
  ];
}

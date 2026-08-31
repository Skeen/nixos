# LunarVim's default colorscheme (lunarvim/lunar.nvim), which is not packaged in
# nixpkgs. Vendored here since LunarVim was removed from nixpkgs.
{
  lib,
  fetchFromGitHub,
  vimUtils,
}: let
  src = fetchFromGitHub {
    owner = "lunarvim";
    repo = "lunar.nvim";
    rev = "08bbc93b96ad698d22fc2aa01805786bcedc34b9";
    hash = "sha256-OBhADgq3MLUu+n0fvxGMM0s7CCZyQVghFMpA6ns7SNk=";
  };
in
  vimUtils.buildVimPlugin {
    pname = "lunar-nvim";
    version = "unstable-2024-06-28";
    inherit src;
    meta = {
      description = "LunarVim colorscheme";
      homepage = "https://github.com/lunarvim/lunar.nvim";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }

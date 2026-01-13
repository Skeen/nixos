{...}: {
  # Run unpatched dynamic binaries on NixOS.
  # https://github.com/Mic92/nix-ld
  # This is for instance needed to run pre-commit, as it pulls in outside binaries
  programs.nix-ld.enable = true;
}

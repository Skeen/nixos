{ pkgs, ... }: {
  programs.fish.enable = true;

  users.users.emil = {
    shell = pkgs.fish;
  };
}

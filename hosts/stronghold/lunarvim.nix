{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    (lunarvim.override {
      viAlias = true;
      vimAlias = true;
      nvimAlias = true;
    })
  ];
  environment.variables.EDITOR = "lvim";
}

{ pkgs, ... }: {
  nixpkgs.config.permittedInsecurePackages = [
    "electron-36.9.5"
  ];

  users.users.emil = {
    packages = with pkgs; [
      (heroic.override {
        extraPkgs = pkgs: [
          pkgs.gamescope
        ];
      })
    ];
  };
}

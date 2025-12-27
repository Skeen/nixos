{lib, pkgs, ...}: {
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "discord"
    ];

  users.users.emil.packages = with pkgs; [
    discord
  ];
}

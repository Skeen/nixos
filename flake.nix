{
  description = "NixOS system";

  inputs = {
    secrets = {
      url = "git+ssh://git@github.com/Skeen/nixos-secret.git";
    };
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-25.05";
    };
    nixpkgs-unstable = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs"; # use the same nixpkgs as the system
      inputs.home-manager.follows = "home-manager"; # use the same home-manager as the system
      inputs.darwin.follows = ""; # don't download dawrin dependencies
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs"; # use the same nixpkgs as the system
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs"; # use the same nixpkgs as the system
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable"; # use nixpkgs-unstable
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: {
    # https://kamadorueda.com/alejandra/
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
    formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.alejandra;

    nixosConfigurations = {
      # Work laptop
      anvil = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = inputs; # pass flake inputs to modules
        modules = [./hosts/anvil];
      };
      # Stationary Virtual Machine
      hearth = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = inputs; # pass flake inputs to modules
        modules = [./hosts/hearth];
      };
    };
  };
}

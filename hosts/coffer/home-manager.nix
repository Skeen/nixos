{
  config,
  home-manager,
  ...
}: {
  # Like NixOS manages the system configuration, Home Manager manages the user
  # environment.
  #
  # A lot of people split their configuration into home/ and nixos/, and import
  # both directly in flake.nix, but on a single-user system I find more value
  # in a structure based on the program or service rather than the
  # implementation-specific details of where the output is saved to disk.
  # https://nix-community.github.io/home-manager/
  # https://wiki.nixos.org/wiki/Home_Manager
  # https://nix-community.github.io/home-manager/options.html

  # Import Home Manager to make it part of the NixOS configuration
  imports = [
    home-manager.nixosModules.home-manager
  ];

  home-manager = {
    # Use the same nixpkgs as the system
    useGlobalPkgs = true;

    # Install packages to /etc/profiles instead of $HOME/.nix-profile.
    # According to the Home Manager documentation, this option may become the
    # default in the future, so it's probably a good idea.
    useUserPackages = true;

    # Define the user and path Home Manager should manage
    users.emil = {
      home = with config.users.users; {
        username = emil.name;
        homeDirectory = emil.home;
        # This value determines the Home Manager release that your
        # configuration is compatible with. This helps avoid breakage
        # when a new Home Manager release introduces backwards
        # incompatible changes.
        # You can update Home Manager without changing this value. See
        # the Home Manager release notes for a list of state version
        # changes in each release.
        stateVersion = "25.05";  # Did you read the comment?
      };

      # Let Home Manager install and manage itself
      programs.home-manager.enable = true;
    };
  };
}

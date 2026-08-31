{
  agenix,
  pkgs,
  ...
}: {
  # Agenix manages the deployment of secrets by public-key encrypting them to
  # each system's ssh host key. See the README for more information.
  # https://github.com/ryantm/agenix
  # https://wiki.nixos.org/wiki/Comparison_of_secret_managing_schemes

  imports = [
    agenix.nixosModules.default
  ];

  # Agenix attempts to decrypt secrets before impermanence symlinks the ssh
  # host key. Refer directly to the key on the persistent partition, which is
  # mounted in stage 1 of the boot process, before agenix runs.
  # https://github.com/ryantm/agenix/issues/45#issuecomment-901383985
  age.identityPaths = ["/nix/persist/etc/ssh/ssh_host_ed25519_key"];

  # `agenix` cli tool
  environment.systemPackages = [
    agenix.packages.${pkgs.system}.default
  ];
}

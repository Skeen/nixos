{agenix, ...}: {
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
  #
  # There is no nixos-anywhere --extra-files for relic: the key is written
  # into system.img before it is flashed (README "Installing relic").
  # Without it nothing decrypts, emil and root end up without a password, and
  # relic has to be reflashed.
  age.identityPaths = ["/nix/persist/etc/ssh/ssh_host_ed25519_key"];

  # Unlike the other hosts, no `agenix` cli tool: secrets are never edited on
  # the phone, and the agenix package is built from the 25.05 nixpkgs, so it
  # would pull a second (25.05) glibc, bash and age onto relic.
}

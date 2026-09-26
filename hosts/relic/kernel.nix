{
  config,
  lib,
  pkgs,
  mobile-nixos,
  ...
}: let
  # nixpkgs cross-compiling from x86_64 to aarch64, with the same overlays
  # (including the Mobile NixOS ones) and config as the system.
  crossPkgs = import pkgs.path {
    localSystem = "x86_64-linux";
    crossSystem = "aarch64-linux";
    inherit (config.nixpkgs) overlays config;
  };
in {
  # relic runs the sdm845-mainline kernel packaged by Mobile NixOS. Nothing
  # caches it (the Mobile NixOS Hydra jobset has been disabled since 2024), so
  # it is built from source, and it is rebuilt whenever nixpkgs-unstable is
  # bumped because it is built with nixpkgs' toolchain and kernel helpers.
  #
  # Everything else is built natively for aarch64 (and mostly substituted from
  # cache.nixos.org) through hearth's binfmt emulation. The kernel is the one
  # heavy build, which takes hours under qemu, so build the same kernel
  # expression with a cross compiler that runs natively on hearth. The cross
  # toolchain is in the binary cache. Every driver is built in (no `=m` in its
  # config), and the system's boot.kernelPackages resolves to this same build,
  # so there is no module ABI to keep in sync with the rest of the system.
  #
  # NOTE: relic can now only be built on an x86_64 machine (hearth), never on
  # relic itself or on granary/coffer.
  mobile.boot.stage-1.kernel.package = lib.mkForce (
    crossPkgs.callPackage "${mobile-nixos}/devices/families/sdm845-mainline/kernel" {}
  );
}

{
  config,
  lib,
  ...
}: {
  # Mobile NixOS builds system.img (mobile.generatedFilesystems.rootfs) for a
  # persistent ext4 "/": the closure sits at /nix/store inside the image, and
  # the Nix database registration at /nix-path-registration. relic mounts that
  # image at /nix instead (./hardware.nix), so the image needs a few additions
  # for the first boot.
  #
  # The upstream rootfs definition is lib.mkDefault as a whole. Defining it at
  # the same priority merges with it (populateCommands are concatenated);
  # a plain definition would replace it.
  mobile.generatedFilesystems.rootfs = lib.mkDefault {
    populateCommands = lib.mkAfter ''
      # The sources of the stage-1 bind mounts must exist on first boot, or
      # stage-1 waits for them until it times out.
      mkdir -p ./persist/etc/ssh ./persist/var/lib/nixos ./persist/var/log
      chmod 0755 ./persist ./persist/etc ./persist/etc/ssh ./persist/var \
        ./persist/var/lib ./persist/var/lib/nixos ./persist/var/log

      # Stage-1 boots /nix/var/nix/profiles/system. Its fallback (reading
      # /nix-path-registration) only looks on "/", which is tmpfs here.
      mkdir -p ./nix/var/nix/profiles
      ln -s ${config.system.build.toplevel} ./nix/var/nix/profiles/system-1-link
      ln -s system-1-link ./nix/var/nix/profiles/system
    '';
  };

  # Upstream registers the closure from /nix-path-registration on first boot;
  # in this layout the file is at /nix/nix-path-registration.
  boot.postBootCommands = lib.mkAfter ''
    if [ -f /nix/nix-path-registration ]; then
      ${config.nix.package.out}/bin/nix-store --load-db < /nix/nix-path-registration
      rm -f /nix/nix-path-registration
    fi
  '';
}

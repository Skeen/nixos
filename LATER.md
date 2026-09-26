# Later: relic

What is left before relic (OnePlus 6, Mobile NixOS + Phosh) is running.
The step-by-step commands are in README.md, "Installing relic".

## Before installing

- [ ] Commit the staged relic change (`feat(relic): add new host`).
- [ ] In `nixos-secret` (README "Add relic's secrets"):
  - generate relic's host key (README "Adding a new host" step 4)
  - add `relic` to the `let` block and to `all`
  - add `relic` to `"home-wifi-password-file.env.age"` (it does not use
    `all`)
  - add `"relic-ssh-host-key.age" = [];` and
    `"relic-luks-passphrase.age" = [];`
  - `agenix -e` both new secrets (the passphrase must be plain ASCII, it is
    typed on an on-screen keyboard), rekey, commit, push
- [ ] Back in this repo: `nix flake update secrets`, commit as
  `chore(flake): update secrets input to include relic`.
- [ ] Check the phone: is it a carrier variant (e.g. T-Mobile A6013, which
  needs an unlock token)? 6 or 8 GB RAM? (`/` is a tmpfs of 25% of RAM.)
- [ ] Put both A/B slots on the latest OxygenOS 11 firmware, then OEM unlock
  (README "Prepare the phone").

## Installing

- [ ] Build the images, inject the host key and check it prints relic's key,
  encrypt, flash (README "Build the images" and "Flash").
- [ ] Before flashing: `fastboot getvar partition-size:boot_a` must be larger
  than boot.img (39 MB when relic was added).
- [ ] Optional smoke test first: `fastboot boot $out/boot.img`, the splash and
  the LUKS prompt should appear and take touch input.

## After the first boot

- [ ] `systemctl status boot-control systemd-growfs@nix` both succeeded, and
  `df -h /nix` shows all of userdata.
- [ ] `findmnt`: tmpfs `/`, `/nix` on `/dev/mapper/relic`, plus the binds.
- [ ] Re-tune the LUKS key derivation on the phone (`cryptsetup
  luksConvertKey`, README "First boot").
- [ ] Back up the modem partitions `modemst1`, `modemst2`, `fsg` and `fsc`
  (under `/dev/disk/by-partlabel`) off the phone; they hold the IMEI.
- [ ] Check what was only inferred, not tested:
  - the on-screen keyboard unfolds by itself in text fields
  - the display connector is `DSI-1` (`wlr-randr`), and scale 2.5 looks
    right (`hosts/relic/phosh/session.nix`)
  - home Wi-Fi connects, an SMS arrives in chatty
- [ ] Switch to a new generation, reboot, and check `readlink
  /run/current-system` is the new one (upstream #851 reports it coming back
  on the old one).

## Known gaps (6.4 kernel / Mobile NixOS)

- Calls connect but have no audio: needs q6voiced plus a UCM "Voice Call"
  verb for the OnePlus 6 (see `hosts/relic/network.nix`).
- No mobile data: the kernel lacks `CONFIG_RMNET` (mobile-nixos#830).
- No auto-rotate, ambient light or proximity: the sensors need hexagonrpcd
  and the OnePlus sensor registry.
- No camera driver.
- If Phosh bootloops (mobile-nixos#851): use the bring-up block in
  `hosts/relic/mobile-nixos.nix` and check `/var/lib/systemd/pstore`.

## Maintenance

- `nixos-rebuild switch` never rewrites boot.img. Reflash it after bumping
  `mobile-nixos` or changing `hosts/relic/{mobile-nixos,kernel,hardware}.nix`
  or `udev-retrigger.rb` (README "Updating relic").
- relic's closure (5.6 GiB) must stay below hearth's 7.8 GiB tmpfs build
  directory, or the system.img build fails with "No space left on device".
- The four `programs.git.*` rename warnings from `modules/base/git.nix` go
  away once all hosts move to Home Manager 25.11 or later.

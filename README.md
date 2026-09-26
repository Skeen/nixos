# NixOS

Flake-based multi-host NixOS.

Secrets live in the private [`nixos-secret`](https://github.com/Skeen/nixos-secret)
input, encrypted with [agenix](https://github.com/ryantm/agenix) using each host's ssh
host key.

## Refreshing

```bash
sudo nixos-rebuild switch --flake . --override-input secrets ./../nixos-secret/
```

### Remote

From another host (e.g. anvil from hearth):
```bash
nixos-rebuild switch --flake .#anvil --target-host emil@192.168.178.145 \
  --use-remote-sudo --override-input secrets ../nixos-secret
```

## Installing

Two machines are involved:
- The **source**: an existing working NixOS machine you drive the install from,
  with the `nixos` and `nixos-secret` repositories checked out and the NixOS
  recovery age key (from Proton Pass) available.
- The **target**: the machine being installed, reachable from the source over
  SSH. It will be wiped during install.

### Prepare the target

1. Boot the target into any Linux with root SSH access.

   The [NixOS live ISO](https://nixos.org/download/) on a USB stick is the easy
   choice, and provides `nixos-generate-config` needed when adding a new host.

2. Ensure that it's reachable from the **source**.

   On the NixOS live ISO, set a root password so SSH works (`sudo passwd root`).

3. Note its address (or provide one yourself in the next step):
   ```bash
   ip addr
   ```

This concludes preparing the target; leave it running.

The rest of the instructions happen on the source machine.

### Prepare the source

1. Set the target's address from the previous section:
   ```fish
   set TARGET root@192.168.1.50
   ```

2. Read the NixOS recovery key (from Proton Pass) into a temporary file:
   ```fish
   set AGE_KEY_FILE (mktemp); read -s > $AGE_KEY_FILE
   ```

### Adding a new host

If you are reinstalling a host already in `flake.nix`, skip this section.

1. Pick a name for the new host and set it (the flake attribute):
   ```fish
   set HOST <name>
   ```

2. Create `hosts/$HOST/` by copying an existing host, and register it in
   `flake.nix`.

3. Pull the target's disk id and hardware config into it (disko owns the
   filesystems, so exclude them):
   ```fish
   ssh $TARGET ls -l /dev/disk/by-id
   ssh $TARGET nixos-generate-config --no-filesystems --show-hardware-config \
     > hosts/$HOST/hardware.nix
   ```
   Set the disk in `disko.nix` to the by-id path.

4. Generate the host key and print its public half:
   ```fish
   set tmp (mktemp -d)
   ssh-keygen -t ed25519 -N "" -C "root@$HOST" -f "$tmp/ssh_host_ed25519_key"
   cat "$tmp/ssh_host_ed25519_key.pub"
   ```

5. Navigate to the secret checkout (where `secrets.nix` lives).

6. Add the host to `secrets.nix` - put it in the `let` block (and `all`), then
   declare its rules:
   ```nix
   <host> = "<the .pub printed above>";
   "<host>-ssh-host-key.age" = [];            # recovery-only backup
   "<host>-luks-passphrase.age" = [<host>];   # encrypted hosts only
   ```
   Import the private key (paste `$tmp/ssh_host_ed25519_key` into the editor),
   create the passphrase, rekey, and push:
   ```fish
   agenix -e "$HOST-ssh-host-key.age"
   agenix -e "$HOST-luks-passphrase.age"
   agenix -r -i "$AGE_KEY_FILE"
   git add -A
   git commit -m "feat($HOST): add luks and ssh-host-key for nixos-anywhere bootstrap"
   git push
   ```

The new host is now a first-class citizen, its configuration and secrets
indistinguishable from any existing host's.

### Installing a host

(Re)installs a host already in `flake.nix` using
[`nixos-anywhere`](https://github.com/nix-community/nixos-anywhere) from the
source.

1. Set `HOST` to the flake attribute you want to deploy:
   ```fish
   set HOST anvil
   ```

2. Navigate to the secret checkout (where `secrets.nix` lives).

3. Reconstruct the host key into an `--extra-files` tree:
   ```fish
   set extra (mktemp -d)
   mkdir -p "$extra/nix/persist/etc/ssh"
   chmod 755 "$extra/nix/persist/etc/ssh"
   agenix -d "$HOST-ssh-host-key.age" -i "$AGE_KEY_FILE" \
     > "$extra/nix/persist/etc/ssh/ssh_host_ed25519_key"
   chmod 600 "$extra/nix/persist/etc/ssh/ssh_host_ed25519_key"
   ssh-keygen -y -f "$extra/nix/persist/etc/ssh/ssh_host_ed25519_key" \
     > "$extra/nix/persist/etc/ssh/ssh_host_ed25519_key.pub"
   ```

4. Encrypted hosts only - decrypt the LUKS passphrase (remote path must match
   `passwordFile` in the host's `disko.nix`):
   ```fish
   agenix -d "$HOST-luks-passphrase.age" -i "$AGE_KEY_FILE" > /tmp/luks.key
   ```

5. Return to the nixos repo, build against the secret checkout, and deploy:
   ```fish
   set disko (nix build --no-link --print-out-paths \
     ".#nixosConfigurations.$HOST.config.system.build.diskoScript" \
     --override-input secrets ../nixos-secret)
   set top (nix build --no-link --print-out-paths \
     ".#nixosConfigurations.$HOST.config.system.build.toplevel" \
     --override-input secrets ../nixos-secret)

   nix run github:nix-community/nixos-anywhere -- \
     --store-paths "$disko" "$top" \
     --disk-encryption-keys /tmp/luks.key /tmp/luks.key \
     --extra-files "$extra" \
     --target-host "$TARGET"
   ```

Drop `--disk-encryption-keys` for unencrypted hosts.

### Installing relic

relic (OnePlus 6, running
[Mobile NixOS](https://mobile.nixos.org/devices/oneplus-enchilada.html))
cannot be installed with `nixos-anywhere`. It is flashed over USB with
fastboot from hearth, which builds relic's aarch64 system through binfmt.
Mobile NixOS builds two images:
- `boot.img` (the kernel and the Mobile NixOS stage-1) goes to the `boot`
  partitions.
- `system.img` (an ext4 filesystem holding the whole system) goes to
  `userdata`, once the host key is written into it and it is encrypted.

`adb` and `fastboot` are provided by `nix shell nixpkgs#android-tools`.

#### Prepare the phone

1. On stock OxygenOS, update to the latest OxygenOS 11 and make sure both A/B
   slots carry the same firmware, either by installing the full OTA zip once
   more (Settings > System > System updates > cog > Local upgrade) or by
   flashing LineageOS' `copy-partitions` zip from a recovery, see
   https://wiki.lineageos.org/devices/enchilada/install#ensuring-all-firmware-partitions-are-consistent

2. Enable Developer options > "OEM unlocking" and "USB debugging", then unlock
   the bootloader (this wipes the phone):
   ```fish
   adb reboot bootloader # or: power off, then hold Power + Volume Up
   fastboot oem unlock
   ```

#### Add relic's secrets

Set `AGE_KEY_FILE` as in [Prepare the source](#prepare-the-source) step 2
(step 1 does not apply), then follow
[Adding a new host](#adding-a-new-host) steps 4 to 6 with `set HOST relic`
(step 3 does not apply, relic has no disko). Add `relic` to `all` (for the
shared password) and to the home wifi rule. The LUKS passphrase is only ever
decrypted on the source, so its rule has no host:
```nix
"home-wifi-password-file.env.age" = [anvil satchel relic];
"relic-ssh-host-key.age" = [];
"relic-luks-passphrase.age" = [];
```
The passphrase is typed on an on-screen keyboard at every boot, so stick to
ASCII letters, digits and common symbols.

Then update the secrets input in this repository:
```fish
nix flake update secrets
```

#### Build the images

1. Build (the first build takes long):
   ```fish
   set out (nix build --no-link --print-out-paths \
     ".#nixosConfigurations.relic.config.mobile.outputs.android.android-fastboot-images" \
     --override-input secrets ../nixos-secret)
   ```
   `system.img` is staged in the nix-daemon's build directory, a RAM-backed
   tmpfs on hearth (7.8 GiB), which must hold relic's whole closure (5.6 GiB
   when relic was added, see `hosts/relic/firmware.nix`). "No space left on
   device" from `filesystem-image` means the closure outgrew it.

2. Copy `system.img` somewhere writable and disk-backed:
   ```fish
   set work (mktemp -d -p /var/tmp)
   install -m 600 $out/system.img $work/system.img
   ```

3. Navigate to the secret checkout, and write the host key into the image. The
   image is mounted at `/nix` on relic, so its `/persist` is `/nix/persist`:
   ```fish
   agenix -d relic-ssh-host-key.age -i "$AGE_KEY_FILE" \
     > $work/ssh_host_ed25519_key
   chmod 600 $work/ssh_host_ed25519_key
   ssh-keygen -y -f $work/ssh_host_ed25519_key > $work/ssh_host_ed25519_key.pub
   printf '%s\n' \
     "cd /persist/etc/ssh" \
     "write $work/ssh_host_ed25519_key ssh_host_ed25519_key" \
     "write $work/ssh_host_ed25519_key.pub ssh_host_ed25519_key.pub" \
     "sif ssh_host_ed25519_key mode 0100600" \
     "sif ssh_host_ed25519_key uid 0" \
     "sif ssh_host_ed25519_key gid 0" \
     "sif ssh_host_ed25519_key.pub mode 0100644" \
     "sif ssh_host_ed25519_key.pub uid 0" \
     "sif ssh_host_ed25519_key.pub gid 0" \
     | nix shell nixpkgs#e2fsprogs -c debugfs -w -f - $work/system.img
   nix shell nixpkgs#e2fsprogs -c e2fsck -fn $work/system.img
   # Must print relic's key from secrets.nix. If it prints nothing or another
   # key, redo from step 2: debugfs does not overwrite existing files
   nix shell nixpkgs#e2fsprogs -c debugfs \
     -R "cat /persist/etc/ssh/ssh_host_ed25519_key.pub" $work/system.img
   ```

4. Encrypt the image in place. cryptsetup reads the passphrase from stdin up
   to the first newline, the same way stage-1 hands it over. The key
   derivation is capped so the phone does not take ages to unlock; it is
   re-tuned on the phone after the first boot:
   ```fish
   truncate -s +32M $work/system.img
   agenix -d relic-luks-passphrase.age -i "$AGE_KEY_FILE" \
     | nix shell nixpkgs#cryptsetup -c cryptsetup reencrypt --encrypt \
       --type luks2 --sector-size 4096 --reduce-device-size 32M \
       --pbkdf argon2id --pbkdf-memory 262144 --iter-time 1000 \
       $work/system.img
   ```

#### Flash

Put the phone in fastboot mode (power off, then hold Power + Volume Up), and
from the nixos repo:
```fish
fastboot getvar partition-size:boot_a # must be larger than $out/boot.img
fastboot erase dtbo_a # the mainline kernel needs dtbo gone, which also
fastboot erase dtbo_b # means Android no longer boots
fastboot flash --slot=all boot $out/boot.img
fastboot flash userdata $work/system.img
fastboot reboot
rm -r $work
```

To try a new `boot.img` without flashing it, `fastboot boot $out/boot.img`.

#### First boot

Enter the LUKS passphrase on the stage-1 on-screen keyboard, then unlock Phosh
with the usual password (the keyboard button next to the keypad opens the
on-screen keyboard). relic joins the home wifi; find its address in
Settings > Wi-Fi, and from hearth:
```fish
ssh emil@<ip>
systemctl status boot-control systemd-growfs@nix # both must have succeeded
df -h /nix # /nix fills userdata
# Re-tune the LUKS key derivation for the phone's CPU
sudo cryptsetup luksConvertKey --pbkdf argon2id --iter-time 2000 \
  /dev/disk/by-partlabel/userdata
```

Back up the modem calibration partitions (`modemst1`, `modemst2`, `fsg` and
`fsc` under `/dev/disk/by-partlabel`) off the phone; they hold the IMEI and
are rewritten by the modem.

#### Updating relic

Userland deploys like any other host. `--fast` stops `nixos-rebuild` from
re-executing relic's own aarch64 `nixos-rebuild` on hearth, and the
"do not know how to make this configuration bootable" warning is expected:
```fish
nixos-rebuild switch --fast --flake .#relic --target-host emil@<ip> \
  --use-remote-sudo --override-input secrets ../nixos-secret
```

`boot.img` (the kernel, stage-1, LUKS, the kernel command line and the
filesystems needed for boot) only changes by reflashing it. That is needed
after bumping `mobile-nixos` or changing `hosts/relic/mobile-nixos.nix`,
`kernel.nix`, `hardware.nix` or `udev-retrigger.rb`; after a plain nixpkgs
bump, the flashed kernel keeps working:
```fish
set bootimg (nix build --no-link --print-out-paths \
  ".#nixosConfigurations.relic.config.mobile.outputs.android.android-bootimg" \
  --override-input secrets ../nixos-secret)
ssh -t emil@<ip> sudo systemctl reboot --reboot-argument=bootloader
fastboot boot $bootimg # try it once without flashing
# If it boots fine, return to fastboot and make it permanent
fastboot flash --slot=all boot $bootimg
fastboot reboot
```

To roll back userland, hold a volume key right after submitting the LUKS
passphrase until the generation menu appears (stage-1 only checks the keys at
that point), and pick an older generation. A broken `boot.img` is recovered by
flashing a previous one from fastboot (power off, then hold Power + Volume
Up).

## References

Heavily inspired by: https://git.caspervk.net/caspervk/nixos

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


## Editor (lvim)

LunarVim (upstream-abandoned) was replaced by a [NixVim](https://github.com/nix-community/nixvim)
configuration that reproduces LunarVim 1.4's default behaviour, see
`modules/editor/`. All hosts get `lvim` (plus `vi`/`vim`/`nvim` aliases) with
`NVIM_APPNAME=lvim`, so existing `~/.config/lvim` state keeps working.

### Behavior notes

The NixVim build matches LunarVim 1.4 defaults (options, keymaps, leader menus,
LSP buffer mappings, diagnostics, telescope/which-key/tree/gitsigns/configs)
and keeps existing LunarVim state (`~/.config/lvim`, `~/.local/share/lvim`,
`~/.cache/lvim`) because the editor still runs with `NVIM_APPNAME=lvim`.
Verified equivalent by a 20-scenario keystroke harness driving both editors in
tmux and diffing the resulting work trees (see
`/tmp/opencode/harness/run-scenario.sh` in the dev sandbox). Known cosmetic
differences: which-key v3 footer wording ("back" vs "go up one level") and
`LvimReload` being a best-effort no-op (the config is nix-managed).

## References

Heavily inspired by: https://git.caspervk.net/caspervk/nixos

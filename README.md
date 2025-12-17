# Getting started

1. Download the Graphical ISO image from: https://nixos.org/download/

2. Put the ISO image on a USB drive and boot into the live CD

3. Using the booted live environment, configure the disk using `parted`:

```bash
#!/usr/bin/env bash
set -x

IDENTIFIER="/dev/sda"

# Create partition table
parted "${IDENTIFIER}" -- mklabel gpt

# Create /boot partition
parted "${IDENTIFIER}" -- mkpart ESP fat32 1MiB 1024MiB
parted "${IDENTIFIER}" -- set 1 esp on

# Create /nix partition
parted "${IDENTIFIER}" -- mkpart primary 1024MiB 100%

# Create and open LUKS-encrypted container
cryptsetup --type=luks2 luksFormat --label=crypted "${IDENTIFIER}2"
cryptsetup open "${IDENTIFIER}2" crypted

# Create LVM volume group
pvcreate /dev/mapper/crypted
vgcreate vg /dev/mapper/crypted

# Create root logical volume
lvcreate -l 100%FREE vg -n root

# Format partitions
mkfs.fat -F32 -n BOOT "${IDENTIFIER}1"
mkfs.ext4 -L nix /dev/vg/root
```
The result should be the following (`lsblk -f`):
```
NAME          FSTYPE      FSVER            LABEL
sda
├─sda1        vfat        FAT32            BOOT
└─sda2        crypto_LUKS 2                crypted
  └─crypted   LVM2_member LVM2 001
    └─vg-root ext4        1.0              nix
```

4. Mount the newly created partitions:

```bash
# Mount tmpfs to /mnt
mount -t tmpfs none /mnt
# Mount our boot disk to /mnt/boot
mount --mkdir /dev/disk/by-label/BOOT /mnt/boot
# Mount our nix disk to /mnt/nix
mount --mkdir /dev/disk/by-label/nix /mnt/nix
# Create a folder for files we wish to persist
mkdir -p /mnt/nix/persist/
```

5. Generate a host-key for the system

```bash
mkdir -p /mnt/nix/persist/etc/ssh/
ssh-keygen -A -f /mnt/nix/persist
```
Then extract the public key to an existing machine:
```
cat /mnt/nix/persist/etc/ssh/ssh_host_ed25519_key.pub
```
This could be done using netcat (`nc`) or similar.

6. Generate the NixOS hardware-config and export it to an existing machine:
```bash
nixos-generate-config --root /mnt --show-hardware-config
```

7. Generate an SSH key on the machine

```bash
ssh-keygen -t ed25519
```
Then extract the public key to an existing machine:
```bash
cat /root/.ssh/id_ed25519.pub
```

8. Switch to an already trusted machine

9. Decide on a hostname for the new machine

10. Rekey all secrets in the `nixos-secret` repository using the host-key (from 5):

See the README on https://github.com/Skeen/nixos-secret for details

11. Prepare configuration for the new machine using the hardware config (from 6):

TODO: FINISH THIS

12. Add the SSH key (From 7) to GitHub allowing the new machine to clone:

```bash
cd /mnt/nix
git clone git@github.com:Skeen/nixos.git
git clone git@github.com:Skeen/nixos-secret.git
```

13. Install NixOS using the prepared configuration

```bash
nixos-install --no-root-passwd --flake .#chosen-hostname
```

# Refreshing
```bash
sudo nixos-rebuild switch --flake . --override-input secrets ./../nixos-secret/
```

# Running on virt-manager

Make sure to install `ovmf` and configure the VM for UEFI boot.

# References

This repository and its configuration is heavily inspired by: https://git.caspervk.net/caspervk/nixos

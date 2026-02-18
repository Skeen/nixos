{config, secrets, ...}: {
  # Setup decryption of NVME
  environment.etc."crypttab".text = ''
    # Name 	path				keyfile
    mediavault	/dev/disk/by-label/crypted 	${config.age.secrets.granary-jellyfin-nvme-luks-key-file.path}
  '';

  # Mount the decrypted media storage to /mnt/media
  fileSystems."/mnt/media" = {
    device = "/dev/mapper/mediavault";
    fsType = "ext4";
    options = [ "defaults" "nofail" "noatime" ];
  };

  # Ensure jellyfin can access the folder
  systemd.tmpfiles.rules = [
     "d /mnt/media 0775 jellyfin torrent -"
  ];

  # Enable SDD trim to ensure SSD health
  services.fstrim.enable = true;

  # Ensure the torrent group exists
  users.groups.torrent = {
    members = ["emil" "jellyfin"];
  };

  # Jellyfin is a free and open-source media server and suite of multimedia
  # applications designed to organize, manage, and share digital media files to
  # networked devices.
  # https://jellyfin.org/
  # NOTE: Jellyfin config is not managed by NixOS. Here's how to set it up:
  # * Media Libraries:
  #   * Shows: /srv/torrents/tv/.
  #     * Disable all metadata download; will be gathered from Sonarr's .nfo's instead.
  #   * Movies: /srv/torrents/downloads/movies/.
  # * 'Allow remote connections to this server' should remain **enabled** even
  #   though we are using a reverse proxy.
  # * Install 'Kodi Sync Queue' under 'Admin/Plugins/Catalog'.
  services.jellyfin = {
    enable = true;
    # Use the 'torrent' group to share files amongst downloaders, indexers etc.
    group = "torrent";

    openFirewall = true;
  };

  environment.persistence."/nix/persist" = {
    directories = [
      {
        directory = "/var/lib/jellyfin";
        user = "jellyfin";
        group = "torrent";
        mode = "0700";
      }
    ];
  };

  age.secrets.granary-jellyfin-nvme-luks-key-file = {
    file = "${secrets}/secrets/granary-jellyfin-nvme-luks-key.age";
    mode = "400";
    owner = "root";
    group = "root";
  };
}

{
  lib,
  pkgs,
  ...
}: {
  # The Mobile NixOS sdm845 family enables enableRedistributableFirmware,
  # which puts all of linux-firmware (1.8 GiB, almost all of it for other
  # hardware) on the phone twice: zstd-compressed in the firmware directory,
  # and uncompressed through the sdm845 modem quirk, whose buildEnv over every
  # hardware.firmware entry keeps linux-firmware in the closure. That was 2.5
  # GiB of an 8.1 GiB closure, and system.img is staged in the nix-daemon's
  # build directory, which is a RAM-backed tmpfs on hearth.
  #
  # Every firmware-name in the OnePlus 6 device tree (DSPs, modem, GPU zap
  # shader, Venus, IPA, Bluetooth NVM) points into the device firmware that
  # Mobile NixOS adds itself (oneplus-sdm845-firmware), which also wins the
  # collisions with linux-firmware (ath10k board-2.bin, qca/crbtfw21.tlv).
  # Only the files drivers request by their built-in names are left to take
  # from linux-firmware:
  #  - qcom/a630_{sqe.fw,gmu.bin}: Adreno 630 GPU (msm)
  #  - ath10k/WCN3990/hw1.0/firmware-5.bin: WCN3990 Wi-Fi (ath10k_snoc)
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.firmware = [
    (pkgs.runCommand "linux-firmware-oneplus-enchilada" {} ''
      for f in \
        qcom/a630_sqe.fw \
        qcom/a630_gmu.bin \
        ath10k/WCN3990/hw1.0/firmware-5.bin
      do
        install -D -m 444 ${pkgs.linux-firmware}/lib/firmware/$f $out/lib/firmware/$f
      done
    '')
  ];

  # Enabled by enableRedistributableFirmware before: the wireless regulatory
  # database cfg80211 loads for the Wi-Fi.
  hardware.wirelessRegulatoryDatabase = true;
}

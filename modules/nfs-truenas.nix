# Montages NFS TrueNAS
{ config, lib, pkgs, ... }:

let
  truenasIP = "172.16.16.216";
  nfsOptions = [ "rw" "async" "hard" "_netdev" "noatime" "nfsvers=4" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
in
{
  fileSystems."/mnt/truenas/immich" = {
    device = "${truenasIP}:/mnt/mainpool/immich";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/truenas/paperless" = {
    device = "${truenasIP}:/mnt/mainpool/paperless";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/truenas/frigate" = {
    device = "${truenasIP}:/mnt/mainpool/frigate";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/truenas/booklore-library" = {
    device = "${truenasIP}:/mnt/mainpool/booklore-library";
    fsType = "nfs";
    options = nfsOptions;
  };

  # HUB : copie serveur du Hub (synchronisée depuis le Mac via Syncthing).
  # Monté en /mnt/mac_hub pour compat (chemin historique, renommage prévu en V5/V6).
  # Remplace l'ancien montage CIFS //100.95.204.27/Hub (cf. cifs-mac.nix).
  fileSystems."/mnt/mac_hub" = {
    device = "${truenasIP}:/mnt/mainpool/hub";
    fsType = "nfs";
    options = nfsOptions;
  };
}

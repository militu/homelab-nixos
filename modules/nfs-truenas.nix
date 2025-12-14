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

  fileSystems."/mnt/truenas/booklore-bookdrop" = {
    device = "${truenasIP}:/mnt/mainpool/booklore-bookdrop";
    fsType = "nfs";
    options = nfsOptions;
  };

  fileSystems."/mnt/truenas/booklore-library" = {
    device = "${truenasIP}:/mnt/mainpool/booklore-library";
    fsType = "nfs";
    options = nfsOptions;
  };
}

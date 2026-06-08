# CIFS mounts pour les shares Mac (via Tailscale)
{ config, lib, pkgs, ... }:

{
  # Secret CIFS credentials
  age.secrets.cifs-mac = {
    file = ../secrets/cifs-mac.age;
    mode = "600";
  };

  # Packages nécessaires
  environment.systemPackages = with pkgs; [
    cifs-utils
  ];

  # Créer les points de montage
  # NOTE : /mnt/mac_hub n'est plus monté ici — il est passé en NFS TrueNAS
  # (cf. nfs-truenas.nix : 172.16.16.216:/mnt/mainpool/hub). Ce module ne gère
  # plus que mac_downloads (Téléchargements Mac via CIFS/Tailscale).
  systemd.tmpfiles.rules = [
    "d /mnt/mac_downloads 0755 amadeus users -"
  ];

  # Mount CIFS — Téléchargements Mac uniquement
  fileSystems."/mnt/mac_downloads" = {
    device = "//100.95.204.27/Téléchargements";
    fsType = "cifs";
    options = [
      "credentials=/run/agenix/cifs-mac"
      "uid=1000"
      "gid=100"
      "file_mode=0664"
      "dir_mode=0775"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
    ];
  };
}

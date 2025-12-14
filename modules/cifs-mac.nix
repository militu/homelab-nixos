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
  systemd.tmpfiles.rules = [
    "d /mnt/mac_hub 0755 amadeus users -"
    "d /mnt/mac_downloads 0755 amadeus users -"
  ];

  # Mounts CIFS
  fileSystems."/mnt/mac_hub" = {
    device = "//100.67.138.79/Hub";
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

  fileSystems."/mnt/mac_downloads" = {
    device = "//100.67.138.79/Téléchargements";
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

# Configuration commune à toutes les machines
{ config, lib, pkgs, ... }:

{
  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # NFS support
  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true;

  # Timezone
  time.timeZone = "Europe/Paris";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "amadeus" ];
  };

  # Packages système de base
  environment.systemPackages = with pkgs; [
    vim git wget curl htop
  ];

  # Fish shell (système)
  programs.fish.enable = true;

  # nix-ld pour VS Code Remote et autres binaires dynamiques
  programs.nix-ld.enable = true;

  # SSH
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # QEMU Guest Agent (Proxmox)
  services.qemuGuest.enable = true;

  # Firewall off pour l'instant
  networking.firewall.enable = false;
}

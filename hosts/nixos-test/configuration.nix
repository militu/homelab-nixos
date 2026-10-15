# Configuration nixos-test (VM de test)
{ config, lib, pkgs, ... }:

{
  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/user-amadeus.nix
    ../../modules/k3s.nix
    ../../modules/nfs-truenas.nix
    ../../modules/frigate-storage.nix
    ../../modules/k3s-repo.nix
    ../../modules/cifs-mac.nix
    ../../modules/gpu-amd.nix
  ];

  # Hostname
  networking.hostName = "nixos-test";

  # Network - DHCP (VLAN 10) : 172.16.16.220 est réservée à Sentinel (doc nixos/deployment)
  networking.useDHCP = true;


  system.stateVersion = "25.11";
}

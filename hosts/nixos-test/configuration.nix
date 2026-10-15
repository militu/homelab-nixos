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

  # Root password (temporaire)
  users.users.root.hashedPassword = "$6$4lwIy7ta1iGgyx4I$jRmHGa7TBkG4DlHJRRp2fnkg5OlCVrPlokmm1nYWsMtnAcZS.mfBo1i6JqpWcK0.MhAkRaCdy9hlVuAnsDhBb1";

  system.stateVersion = "25.11";
}

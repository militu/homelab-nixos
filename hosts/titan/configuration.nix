# Configuration titan (VM de production)
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
  ];

  # Hostname
  networking.hostName = "titan";

  # Network - IP statique (ancienne IP de la VM Ubuntu)
  networking = {
    useDHCP = false;
    interfaces.ens18 = {
      ipv4.addresses = [{
        address = "172.16.16.210";
        prefixLength = 24;
      }];
    };
    defaultGateway = "172.16.16.1";
    nameservers = [ "172.16.16.1" "1.1.1.1" ];
  };

  # Root password (temporaire)
  users.users.root.hashedPassword = "$6$4lwIy7ta1iGgyx4I$jRmHGa7TBkG4DlHJRRp2fnkg5OlCVrPlokmm1nYWsMtnAcZS.mfBo1i6JqpWcK0.MhAkRaCdy9hlVuAnsDhBb1";

  # Config spécifique production (plus de RAM, GPU, etc.)
  # À ajuster selon tes besoins

  system.stateVersion = "25.11";
}

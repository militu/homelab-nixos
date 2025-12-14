# Configuration K3s
{ config, lib, pkgs, ... }:

{
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable=traefik"
      "--disable=servicelb"
      "--write-kubeconfig-mode=644"
    ];
  };

  # Ports K3s
  networking.firewall.allowedTCPPorts = [ 6443 ];
}

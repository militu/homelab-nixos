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

    # Arret propre du noeud : kubelet s enregistre comme inhibiteur systemd et termine
    # les pods AVANT que systemd ne commence l extinction. Sans ca, les conteneurs
    # survivent a l arret de k3s (KillMode=process) et bloquent sd-sync en I/O wait.
    # Delais releves vs defauts (30s/10s) : ce noeud fait tourner ~220 pods.
    gracefulNodeShutdown = {
      enable = true;
      shutdownGracePeriod = "60s";
      shutdownGracePeriodCriticalPods = "20s";
    };
  };

  # Ports K3s
  networking.firewall.allowedTCPPorts = [ 6443 ];
}

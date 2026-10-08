# Configuration K3s
{ config, lib, pkgs, ... }:

{
  services.k3s = {
    # Minor version pinned: patches (1.35.x) arrive with the weekly flake update, a minor bump
    # (1.36…) is an explicit decision taken through the `upgrade` skill, never a nightly surprise.
    package = pkgs.k3s_1_36;
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable=traefik"
      "--disable=servicelb"
      # Admin kubeconfig: root and the wheel group only (amadeus), never every local account.
      "--write-kubeconfig-mode=640"
      "--write-kubeconfig-group=wheel"
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

  # Non-interactive kubectl (Jarvis crons, ssh) reads ~/.kube/config: a link to the kubeconfig
  # k3s rewrites at each start, so a renewed client certificate is followed (a stale copy
  # would have expired on 14/12/2026).
  systemd.tmpfiles.rules = [ "L+ /home/amadeus/.kube/config - - - - /etc/rancher/k3s/k3s.yaml" ];

  # Ports K3s
  networking.firewall.allowedTCPPorts = [ 6443 ];
}

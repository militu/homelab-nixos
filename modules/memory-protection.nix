# Protection mémoire pour les nodes k3s single-node.
{ config, lib, pkgs, ... }:

{
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 25;
  };

  services.k3s.extraKubeletConfig = {
    failSwapOn = false;
    memorySwap.swapBehavior = "NoSwap";

    systemReserved = {
      memory = "2Gi";
    };

    kubeReserved = {
      memory = "1Gi";
    };

    evictionHard = {
      "memory.available" = "1Gi";
      "nodefs.available" = "10%";
      "nodefs.inodesFree" = "5%";
      "imagefs.available" = "15%";
    };
  };

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 25;
    extraArgs = [
      "--sort-by-rss"
      "--avoid"
      "(^|/)(sshd|k3s|containerd|systemd|systemd-journald|dbus-daemon|nix-daemon|qemu-ga)( |$)"
    ];
  };
}

# Clone le repo k3s au premier boot
{ config, lib, pkgs, ... }:

{
  # Service qui clone le repo k3s si pas déjà présent
  systemd.services.clone-k3s-repo = {
    description = "Clone k3s repository";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    # Ne s'exécute que si le dossier n'existe pas
    unitConfig = {
      ConditionPathExists = "!/home/amadeus/k3s";
    };

    path = [ pkgs.openssh ];
    serviceConfig = {
      Type = "oneshot";
      User = "amadeus";
      Group = "users";
      WorkingDirectory = "/home/amadeus";
      ExecStart = "${pkgs.git}/bin/git clone git@github.com:militu/k3s.git /home/amadeus/k3s";
      RemainAfterExit = true;
    };
  };
}

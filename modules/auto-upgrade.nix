# Automatic system upgrades, garbage collection & store optimization
{ config, lib, pkgs, ... }:

{
  # Auto-upgrade: pull config from GitHub and rebuild
  # flake.lock updates are handled via GitHub Actions (nix flake update + PR)
  system.autoUpgrade = {
    enable = true;
    flake = "github:militu/homelab-nixos#titan";
    dates = "*-*-* 04:00:00";
    randomizedDelaySec = "30min";
    allowReboot = false;
    operation = "switch";
  };

  # Heartbeat Gatus (dead-man-switch). Endpoint: titan_nixos-upgrade.
  # ExecStartPost ne tourne que si l'upgrade a réussi ; un échec = silence
  # → alerte après heartbeat.interval (26h). Cf. contrat job NixOS (mécanisme A).
  systemd.services.nixos-upgrade.serviceConfig.ExecStartPost =
    toString (pkgs.writeShellScript "nixos-upgrade-heartbeat" ''
      TOKEN="$(cat ${config.age.secrets.gatus-push-token.path})"
      ${pkgs.curl}/bin/curl -sf -m 10 -X POST -H "Authorization: Bearer $TOKEN" \
        "https://gatus.lemasdelacolline.xyz/api/v1/endpoints/titan_nixos-upgrade/external?success=true" \
        >/dev/null || true
    '');

  # Garbage collection - remove generations older than 30 days
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Store optimization (hard-link identical files, ~25-35% space saved)
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };
}

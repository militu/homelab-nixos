# Claude Code scheduled tasks (systemd timers)
{ config, lib, pkgs, ... }:

{
  # Token de push Gatus (heartbeat dead-man-switch). Déchiffré au boot vers /run/agenix.
  age.secrets.gatus-push-token = {
    file = ../secrets/gatus-push-token.age;
    owner = "amadeus";
  };

  # Token OAuth long-lived Claude Code (claude setup-token, ~1 an) : la session
  # interactive de ~/.claude/.credentials.json expire (cas vécu le 2026-08-05).
  age.secrets.claude-oauth-token = {
    file = ../secrets/claude-oauth-token.age;
    owner = "amadeus";
  };

  # Carte Jarvis : index de boot (HUB/_carte.md) régénéré chaque heure — déterministe, sans LLM.
  systemd.timers."claude-carte" = {
    description = "Régénère HUB/_carte.md (index de boot de Jarvis)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };

  systemd.services."claude-carte" = {
    description = "Génère /mnt/mac_hub/_carte.md depuis les PASSATION.md";
    path = [ pkgs.coreutils pkgs.bash pkgs.curl pkgs.python3 pkgs.kubectl ];
    environment = { HOME = "/home/amadeus"; KUBECONFIG = "/home/amadeus/.kube/config"; };
    serviceConfig = {
      Type = "oneshot";
      User = "amadeus";
      ExecStart = toString (pkgs.writeShellScript "claude-carte" ''
        GATUS="https://gatus.lemasdelacolline.xyz/api/v1/endpoints/titan_claude-carte/external"
        TOKEN="$(cat ${config.age.secrets.gatus-push-token.path})"
        ping() { curl -sf -m 10 -X POST -H "Authorization: Bearer $TOKEN" "$GATUS?success=$1" >/dev/null 2>&1 || true; }
        trap 'ping false' ERR
        set -e
        python3 /home/amadeus/code/homelab-agents/scripts/carte.py \
          --hub /mnt/mac_hub --out /mnt/mac_hub/_carte.md --machine titan
        ping true
      '');
      TimeoutStartSec = "3min";
    };
  };

  # Maintenance Jarvis : contrôle structurel quotidien, déterministe et sans modèle.
  # La revue sémantique (curateur) reste hors automatisation tant qu'elle n'est pas arbitrée.
  systemd.timers."jarvis-hub-check" = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "*-*-* 07:00:00"; Persistent = true; };
  };
  systemd.services."jarvis-hub-check" = {
    description = "Contrôle documentaire déterministe du portefeuille HUB";
    path = [ pkgs.python3 pkgs.coreutils pkgs.curl ];
    environment.MACHINE = "titan";
    serviceConfig = {
      Type = "oneshot"; User = "amadeus"; TimeoutStartSec = "3min";
      ExecStart = toString (pkgs.writeShellScript "jarvis-hub-check" ''
        set -euo pipefail
        ping() {
          { printf 'header = "Authorization: Bearer '; cat ${config.age.secrets.gatus-push-token.path}; printf '"\n'; } |
            curl --config - -sf -m 10 -X POST "https://gatus.lemasdelacolline.xyz/api/v1/endpoints/titan_jarvis-hub-check/external?success=$1" >/dev/null 2>&1 || true
        }
        trap 'ping false' ERR
        python3 /home/amadeus/code/homelab-agents/scripts/hub_check.py --hub /mnt/mac_hub \
          --format markdown --out /mnt/mac_hub/3_DOMAINES/IA/jarvis/04_Notes/controle_automatique.md
        ping true
      '');
    };
  };

  # Surveillance des jetons : rouge 21 j AVANT l'expiration (dates non secrètes dans
  # secrets/expiries.json), plus une vraie sonde Claude (auth + modèle attendu).
  # Filet de la tâche Initiative #110 (ex-rôle de canari du brief du soir, retiré le 03/10/2026).
  systemd.timers."jarvis-token-watch" = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "*-*-* 08:00:00"; Persistent = true; };
  };
  systemd.services."jarvis-token-watch" = {
    description = "Expiration des jetons des jobs Titan + sonde Claude";
    path = [ pkgs.python3 pkgs.coreutils pkgs.curl pkgs.nodejs ];
    environment.HOME = "/home/amadeus";
    serviceConfig = {
      Type = "oneshot"; User = "amadeus"; TimeoutStartSec = "5min";
      ExecStart = toString (pkgs.writeShellScript "jarvis-token-watch" ''
        set -euo pipefail
        ping() {
          { printf 'header = "Authorization: Bearer '; cat ${config.age.secrets.gatus-push-token.path}; printf '"\n'; } |
            curl --config - -sf -m 10 -X POST "https://gatus.lemasdelacolline.xyz/api/v1/endpoints/titan_jarvis-token-watch/external?success=$1" >/dev/null 2>&1 || true
        }
        trap 'ping false' ERR
        export CLAUDE_CODE_OAUTH_TOKEN="$(cat ${config.age.secrets.claude-oauth-token.path})"
        python3 /home/amadeus/code/homelab-agents/scripts/token_watch.py \
          --expiries ${../secrets/expiries.json} --warn-days 21 \
          --claude /home/amadeus/.local/bin/claude --model sonnet --expect-model claude-sonnet-5-5
        ping true
      '');
    };
  };

  # Synchro Initiative → TickTick : Initiative fait référence, TickTick est la vitrine à
  # rappels sur le téléphone (sans Tailscale). Déterministe, sans modèle. Règles :
  # homelab-agents/scripts/ticktick_sync.py. Remplace le brief Pushover de 20 h.
  age.secrets.initiative-sync-token = { file = ../secrets/initiative-sync-token.age; owner = "amadeus"; };
  age.secrets.ticktick-token = { file = ../secrets/ticktick-token.age; owner = "amadeus"; };
  systemd.timers."jarvis-ticktick-sync" = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnBootSec = "2min"; OnUnitActiveSec = "15min"; Persistent = true; };
  };
  systemd.services."jarvis-ticktick-sync" = {
    description = "Synchro des tâches Initiative vers TickTick (et coches en retour)";
    path = [ pkgs.python3 pkgs.coreutils pkgs.curl ];
    serviceConfig = {
      Type = "oneshot"; User = "amadeus"; TimeoutStartSec = "3min";
      ExecStart = toString (pkgs.writeShellScript "jarvis-ticktick-sync" ''
        set -euo pipefail
        ping() {
          { printf 'header = "Authorization: Bearer '; cat ${config.age.secrets.gatus-push-token.path}; printf '"\n'; } |
            curl --config - -sf -m 10 -X POST "https://gatus.lemasdelacolline.xyz/api/v1/endpoints/titan_jarvis-ticktick-sync/external?success=$1" >/dev/null 2>&1 || true
        }
        trap 'ping false' ERR
        python3 /home/amadeus/code/homelab-agents/scripts/ticktick_sync.py \
          --initiative-token ${config.age.secrets.initiative-sync-token.path} \
          --ticktick-token ${config.age.secrets.ticktick-token.path} --guild 2 --list Jarvis
        ping true
      '');
    };
  };
}

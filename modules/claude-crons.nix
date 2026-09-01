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

  systemd.timers."claude-weekly-tasks" = {
    description = "Daily Initiative tasks + Calendar reminder via Pushover";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 20:00:00";
      Persistent = true;
    };
  };

  systemd.services."claude-weekly-tasks" = {
    description = "Send daily Initiative tasks + Calendar summary via Pushover";
    path = [ pkgs.coreutils pkgs.bash pkgs.nodejs pkgs.jq pkgs.curl ];
    environment = {
      HOME = "/home/amadeus";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "amadeus";
      ExecStart = toString (pkgs.writeShellScript "claude-weekly-tasks" ''
        export PATH="/home/amadeus/.nix-profile/bin:$PATH"
        # Heartbeat Gatus (dead-man-switch). Endpoint: titan_claude-weekly-tasks
        GATUS="https://gatus.lemasdelacolline.xyz/api/v1/endpoints/titan_claude-weekly-tasks/external"
        TOKEN="$(cat ${config.age.secrets.gatus-push-token.path})"
        ping() { curl -sf -m 10 -X POST -H "Authorization: Bearer $TOKEN" "$GATUS?success=$1" >/dev/null 2>&1 || true; }
        trap 'ping false' ERR
        set -e
        # pipefail : rend fiable le code de retour du pipeline `cat | claude | tee`
        # (sinon = code de `tee`, toujours 0). Un échec de claude → trap ERR → ping false.
        set -o pipefail
        # Auth headless : token long-lived agenix, prioritaire sur .credentials.json.
        export CLAUDE_CODE_OAUTH_TOKEN="$(cat ${config.age.secrets.claude-oauth-token.path})"
        # RUN_OUT capture la sortie de CE run : claude -p renvoie 0 même sur
        # 'Not logged in' (token OAuth expiré) → détection explicite plus bas.
        RUN_OUT="$(mktemp)"
        cat <<'PROMPT' | /home/amadeus/.local/bin/claude -p \
          --allowedTools "Skill,Read,Glob,mcp__initiative__list_tasks,mcp__initiative__list_projects,mcp__pushover__send_notification,Bash" 2>&1 | tee "$RUN_OUT"
        /orga brief-soir

        CONTEXTE : run planifié (timer Titan 20 h). Aujourd'hui : $(date +%Y-%m-%d). Applique le module
        brief-soir tel quel : une seule notification Pushover, format markdown, corps ≤ 6 lignes ;
        aucune écriture, aucune tâche créée. Si une source est indisponible, une ligne « (indisponible) ».
        PROMPT
        # claude -p renvoie 0 même non authentifié → heartbeat ROUGE + exit 1 sur
        # détection, sinon Gatus resterait faux-vert (cas vécu le 2026-07-07).
        if grep -qiE 'Not logged in|Please run /login' "$RUN_OUT"; then
          echo "[weekly-tasks] ⛔ claude non authentifié — heartbeat rouge"
          rm -f "$RUN_OUT"; ping false; exit 1
        fi
        rm -f "$RUN_OUT"
        ping true
      '');
      TimeoutStartSec = "5min";
    };
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
}

# Claude Code scheduled tasks (systemd timers)
{ config, lib, pkgs, ... }:

{
  # Token de push Gatus (heartbeat dead-man-switch). Déchiffré au boot vers /run/agenix.
  age.secrets.gatus-push-token = {
    file = ../secrets/gatus-push-token.age;
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
        # RUN_OUT capture la sortie de CE run : claude -p renvoie 0 même sur
        # 'Not logged in' (token OAuth expiré) → détection explicite plus bas.
        RUN_OUT="$(mktemp)"
        cat <<'PROMPT' | /home/amadeus/.local/bin/claude -p \
          --allowedTools "mcp__initiative__list_tasks,mcp__initiative__list_projects,mcp__pushover__send_notification,Bash" 2>&1 | tee "$RUN_OUT"
        Tu es mon assistant personnel. Aujourd'hui nous sommes le $(date +%Y-%m-%d). La semaine en cours va du lundi au dimanche.

        1. Récupère les tasks actives :
           mcp__initiative__list_tasks avec status_category=['todo','in_progress'] et guild_id=2
        2. Récupère les events calendar de la semaine via Bash :
           gws calendar events list --params '{"calendarId":"primary","timeMin":"<lundi ISO8601>","timeMax":"<dimanche ISO8601>","singleEvents":true,"orderBy":"startTime","maxResults":50}'
           (calcule les bornes ISO avec date, ex: `date -d 'monday' -Iseconds` et `date -d 'next sunday 23:59' -Iseconds`)
        3. Analyse les due_date des tasks ET les events calendar par rapport à cette semaine
        4. Formate en HTML pour Pushover (UNIQUEMENT ces tags : <b>, <i>, <u>, <a href>)
        5. Envoie via mcp__pushover__send_notification avec format='html'

        Format du body :
        - Ligne 1 : verdict ("RAS cette semaine." ou "⚠️ X deadline(s)/event(s) cette semaine :")
        - Section <b>📅 Events</b> : liste "- titre [jour HH:MM]" (max 8 events, priorise les prochains)
        - Section <b>✅ Tasks</b> par projet : "<b>Projet</b> (N)" puis "- titre [priorite, deadline]"
        - Max 1024 caracteres, priorise les echeances proches

        Si rien : "Aucune tache ni event actif 🎉"
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
}

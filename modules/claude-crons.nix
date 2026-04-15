# Claude Code scheduled tasks (systemd timers)
{ config, lib, pkgs, ... }:

{
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
    path = [ pkgs.coreutils pkgs.bash pkgs.nodejs pkgs.jq ];
    environment = {
      HOME = "/home/amadeus";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "amadeus";
      ExecStart = toString (pkgs.writeShellScript "claude-weekly-tasks" ''
        export PATH="/home/amadeus/.nix-profile/bin:$PATH"
        cat <<'PROMPT' | /home/amadeus/.local/bin/claude -p \
          --allowedTools "mcp__initiative__list_tasks,mcp__initiative__list_projects,mcp__pushover__send_notification,Bash"
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
      '');
      TimeoutStartSec = "5min";
    };
  };
}

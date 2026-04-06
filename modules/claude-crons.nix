# Claude Code scheduled tasks (systemd timers)
{ config, lib, pkgs, ... }:

{
  systemd.timers."claude-weekly-tasks" = {
    description = "Daily Initiative tasks reminder via Pushover";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 20:00:00";
      Persistent = true;
    };
  };

  systemd.services."claude-weekly-tasks" = {
    description = "Send weekly Initiative tasks summary via Pushover";
    path = [ pkgs.coreutils pkgs.bash pkgs.nodejs ];
    environment = {
      HOME = "/home/amadeus";
      PATH = "/home/amadeus/.local/bin:/run/current-system/sw/bin:/usr/bin:/bin";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "amadeus";
      ExecStart = toString (pkgs.writeShellScript "claude-weekly-tasks" ''
        cat <<'PROMPT' | /home/amadeus/.local/bin/claude -p --allowedTools "mcp__initiative__list_tasks,mcp__initiative__list_projects,mcp__pushover__send_notification"
        Tu es mon assistant personnel. Aujourd'hui nous sommes le $(date +%Y-%m-%d). La semaine en cours va du lundi au dimanche.

        1. Utilise mcp__initiative__list_tasks avec status_category=['todo','in_progress'] et guild_id=2
        2. Analyse les due_date par rapport à cette semaine
        3. Formate en HTML pour Pushover (UNIQUEMENT ces tags : <b>, <i>, <u>, <a href>)
        4. Envoie via mcp__pushover__send_notification avec format='html'

        Format du body :
        - Ligne 1 : verdict ("RAS cette semaine." ou "⚠️ X deadline(s) cette semaine :")
        - Puis liste par projet : "<b>Projet</b> (N)" suivi des taches "- titre [priorite, deadline]"
        - Max 1024 caracteres, priorise les deadlines proches

        Si aucune tache : "Aucune tache active 🎉"
        PROMPT
      '');
      TimeoutStartSec = "5min";
    };
  };
}

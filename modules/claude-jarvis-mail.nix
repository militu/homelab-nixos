# Jarvis mail-trigger: forward un mail vers +jarvis → Jarvis le traite
# Gate gratuit (gws) : claude -p n'est lancé QUE s'il y a un mail à traiter.
{ config, lib, pkgs, ... }:

{
  systemd.timers."claude-jarvis-mail" = {
    description = "Poll Gmail +jarvis alias, trigger Jarvis on new instruction mails";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      Persistent = true;
    };
  };

  systemd.services."claude-jarvis-mail" = {
    description = "Process forwarded instruction mails via Jarvis skill";
    path = [ pkgs.coreutils pkgs.bash pkgs.nodejs pkgs.jq ];
    environment = {
      HOME = "/home/amadeus";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "amadeus";
      ExecStart = toString (pkgs.writeShellScript "claude-jarvis-mail" ''
        export PATH="/home/amadeus/.nix-profile/bin:$PATH"

        QUERY="to:mazzeo.victor+jarvis@gmail.com is:unread"

        # --- ÉTAPE 1 : GATE (gratuit, pas de claude) ---
        COUNT=$(gws gmail users messages list \
          --params "{\"userId\":\"me\",\"q\":\"$QUERY\",\"maxResults\":10}" 2>/dev/null \
          | grep -v "keyring backend" \
          | jq -r '.resultSizeEstimate // 0')

        if [ "''${COUNT:-0}" -eq 0 ]; then
          echo "[jarvis-mail] no pending mail, skip."
          exit 0
        fi

        echo "[jarvis-mail] $COUNT mail(s) to process, invoking Jarvis..."

        # --- ÉTAPE 2 : TRAITEMENT (claude -p + skill jarvis + auto-mode) ---
        cat <<'PROMPT' | /home/amadeus/.local/bin/claude -p \
          --permission-mode auto \
          --allowedTools "Skill,Bash,mcp__paperless__post_document,mcp__paperless__list_tags,mcp__paperless__list_correspondents,mcp__paperless__list_document_types,mcp__pushover__send_notification"
        /jarvis

        CONTEXTE : tu es déclenché automatiquement par un mail transféré à l'alias +jarvis.
        Ce sont des instructions que je t'envoie en transférant un mail. Traite-les en mode autonome.

        Pour CHAQUE mail non lu correspondant à la query Gmail
        `to:mazzeo.victor+jarvis@gmail.com is:unread` :

        1. Lis le mail (corps + pièces jointes) via gws :
           - liste : gws gmail users messages list --params '{"userId":"me","q":"to:mazzeo.victor+jarvis@gmail.com is:unread"}'
           - détail : gws gmail users messages get --params '{"userId":"me","id":"<ID>","format":"full"}'
           - pièce jointe : gws gmail users messages attachments get --params '{"userId":"me","messageId":"<ID>","id":"<ATTID>"}' --output /tmp/<nom>
           (filtre toujours la 1ère ligne "Using keyring backend" qui pollue le JSON)
        2. Le CORPS du mail contient mes instructions (ex: "range dans Paperless, tag énergie").
           La/les PIÈCE(S) JOINTE(S) sont le document concerné. Exécute l'action demandée.
        3. Tu es en --permission-mode auto : les actions réversibles passent seules,
           les irréversibles (suppression, paiement, envoi de mail) sont bloquées → ne les tente pas.
        4. Notifie le résultat via mcp__pushover__send_notification (format html, tags <b><i><u><a href>) :
           - succès : "✅ <ce que tu as fait> (<détails: tag, type…>)"
           - blocage/doute : "⚠️ <mail> : <pourquoi tu n'as pas pu / ce qui demande validation>"
        5. Marque le mail comme traité :
           - retire UNREAD + ajoute le label "🤖 Jarvis traité" (crée-le s'il n'existe pas) :
             gws gmail users messages modify --params '{"userId":"me","id":"<ID>"}' \
               --json '{"removeLabelIds":["UNREAD"],"addLabelIds":["<LABELID>"]}'

        Reste concis. Une notif Pushover par mail traité.
        PROMPT
      '');
      TimeoutStartSec = "10min";
    };
  };
}

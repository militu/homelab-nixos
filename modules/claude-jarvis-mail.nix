# Jarvis mail-trigger: forward un mail vers +jarvis → Jarvis le traite
# Gate gratuit (gws) : claude -p n'est lancé QUE s'il y a un mail à traiter.
# Modèle: sonnet (économe). Logs: /home/amadeus/.local/share/jarvis-mail/log/
# Outils: création + lecture uniquement (Paperless, Initiative, Vikunja, Qonto draft,
#         Solidtime, Pushover). AUCUN delete / bulk_edit / batch_update (input email = non fiable).
{ config, lib, pkgs, ... }:

{
  # Clé AES-256 partagée avec l'extension navigateur, pour déchiffrer le cookie Qonto.
  age.secrets.jarvis-qonto-key = {
    file = ../secrets/jarvis-qonto-key.age;
    owner = "amadeus";
    group = "users";
    mode = "600";
  };

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

        LOG_DIR="/home/amadeus/.local/share/jarvis-mail/log"
        mkdir -p "$LOG_DIR"
        LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).log"

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

        # --- COOKIE QONTO : cherche un blob chiffré [JARVIS_QONTO:...] dans les mails ---
        # Si présent, déchiffre (clé AES via agenix) et écris le cookie frais pour le MCP.
        COOKIE_FILE="/run/user/$(id -u)/qonto_cookie"
        AES_KEY_FILE="/run/agenix/jarvis-qonto-key"
        rm -f "$COOKIE_FILE"

        # Récupère le texte brut de tous les mails matchés (décodé base64url) et concatène.
        MAIL_IDS=$(gws gmail users messages list \
          --params "{\"userId\":\"me\",\"q\":\"$QUERY\",\"maxResults\":10}" 2>/dev/null \
          | grep -v "keyring backend" | jq -r '.messages[]?.id')

        BLOB=""
        for mid in $MAIL_IDS; do
          BODY=$(gws gmail users messages get \
            --params "{\"userId\":\"me\",\"id\":\"$mid\",\"format\":\"full\"}" 2>/dev/null \
            | grep -v "keyring backend" \
            | jq -r '[.. | .body?.data? // empty] | map(gsub("-";"+") | gsub("_";"/") | @base64d) | join("\n")' 2>/dev/null)
          FOUND=$(printf '%s' "$BODY" | grep -oE '\[JARVIS_QONTO:[A-Za-z0-9+/=]+\]' | head -1)
          if [ -n "$FOUND" ]; then BLOB="$FOUND"; break; fi
        done

        if [ -n "$BLOB" ] && [ -f "$AES_KEY_FILE" ]; then
          if JARVIS_BLOB="$BLOB" JARVIS_KEYFILE="$AES_KEY_FILE" JARVIS_OUT="$COOKIE_FILE" node -e '
            const crypto=require("crypto"),fs=require("fs");
            const key=Buffer.from(fs.readFileSync(process.env.JARVIS_KEYFILE,"utf8").trim(),"base64");
            const m=process.env.JARVIS_BLOB.match(/\[JARVIS_QONTO:([A-Za-z0-9+/=]+)\]/);
            const buf=Buffer.from(m[1],"base64");
            const iv=buf.subarray(0,12),tag=buf.subarray(buf.length-16),ct=buf.subarray(12,buf.length-16);
            const d=crypto.createDecipheriv("aes-256-gcm",key,iv); d.setAuthTag(tag);
            const cookie=Buffer.concat([d.update(ct),d.final()]).toString("utf8");
            const exp=JSON.parse(Buffer.from(cookie.split(".")[1],"base64").toString()).exp;
            if(exp*1000 < Date.now()){ console.error("cookie expiré"); process.exit(2); }
            fs.writeFileSync(process.env.JARVIS_OUT,cookie,{mode:0o600});
          ' 2>>"$LOG_FILE"; then
            echo "[jarvis-mail] cookie Qonto frais déchiffré → $COOKIE_FILE"
          else
            echo "[jarvis-mail] ⚠️ blob Qonto présent mais déchiffrement/expiration KO (voir log)"
          fi
        fi

        # --- LOG : en-tête de run ---
        {
          echo ""
          echo "==================================================================="
          echo "[$(date +'%Y-%m-%d %H:%M:%S %z')] RUN START — $COUNT mail(s) à traiter"
          echo "==================================================================="
        } >> "$LOG_FILE"

        # --- ÉTAPE 2 : TRAITEMENT (claude -p + skill jarvis + auto-mode) ---
        # stdout+stderr capturés à la fois dans le journal (tee) et dans le log fichier.
        cat <<'PROMPT' | /home/amadeus/.local/bin/claude -p \
          --model sonnet \
          --permission-mode auto \
          --allowedTools "Skill,Bash,mcp__pushover__send_notification,mcp__pushover__send_notification_with_attachment,mcp__paperless__post_document,mcp__paperless__list_documents,mcp__paperless__get_document,mcp__paperless__get_document_content,mcp__paperless__list_tags,mcp__paperless__list_correspondents,mcp__paperless__list_document_types,mcp__paperless__create_tag,mcp__paperless__create_correspondent,mcp__paperless__create_document_type,mcp__initiative__create_task,mcp__initiative__create_subtask,mcp__initiative__create_comment,mcp__initiative__create_tag,mcp__initiative__set_task_tags,mcp__initiative__list_tasks,mcp__initiative__list_projects,mcp__initiative__list_initiatives,mcp__initiative__list_guilds,mcp__initiative__list_tags,mcp__initiative__list_task_statuses,mcp__initiative__get_task,mcp__initiative__get_project,mcp__qonto__list_clients,mcp__qonto__list_client_invoices,mcp__qonto__get_client_invoice,mcp__qonto__create_client_invoice,mcp__solidtime__create_time_entry,mcp__solidtime__create_project,mcp__solidtime__list_projects,mcp__solidtime__list_time_entries,mcp__solidtime__get_project" \
          2>&1 | tee -a "$LOG_FILE"
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
        2. Le CORPS du mail contient mes instructions (ex: "range dans Paperless", "crée une tâche",
           "prépare une facture Qonto pour X", "logue 3h sur projet Y"). Exécute l'action demandée
           en t'appuyant sur ta connaissance de mon système (modules du skill jarvis).
           Les pièces jointes sont les documents concernés.
        3. Tu es en --permission-mode auto avec un set d'outils limité à la CRÉATION et la LECTURE.
           Tu ne peux PAS supprimer, ni modifier en masse, ni finaliser/envoyer une facture
           (Qonto = brouillon uniquement, c'est garanti par l'outil). N'essaie pas ces actions.
           Si une instruction demande quelque chose hors de ce périmètre, ne le fais pas et signale-le.
           Pour une facture Qonto : ignore le marqueur [JARVIS_QONTO:...] dans le mail (c'est le cookie
           d'authentification, déjà géré automatiquement) — appelle simplement create_client_invoice.
           Si l'outil renvoie "session expirée / aucun cookie", c'est que je n'ai pas joint de cookie
           frais : notifie-moi via Pushover de relancer l'extension, ne réessaie pas en boucle.
        4. Notifie le résultat via mcp__pushover__send_notification (format html, tags <b><i><u><a href>) :
           - succès : "✅ <ce que tu as fait> (<détails pertinents : tag, type, client, montant…>)"
           - blocage/doute : "⚠️ <mail> : <pourquoi tu n'as pas pu / ce qui demande validation>"
           Pour une facture Qonto brouillon, indique TOUJOURS client + montant dans la notif.
        5. Marque le mail comme traité :
           - retire UNREAD + ajoute le label "🤖 Jarvis traité" (crée-le s'il n'existe pas) :
             gws gmail users messages modify --params '{"userId":"me","id":"<ID>"}' \
               --json '{"removeLabelIds":["UNREAD"],"addLabelIds":["<LABELID>"]}'

        Reste concis. Une notif Pushover par mail traité.
        PROMPT

        # --- CLEANUP : supprime le cookie frais (ne traîne pas entre deux runs) ---
        rm -f "$COOKIE_FILE"

        # --- LOG : pied de run ---
        echo "[$(date +'%Y-%m-%d %H:%M:%S %z')] RUN END" >> "$LOG_FILE"
      '');
      TimeoutStartSec = "10min";
    };
  };
}

# Configuration utilisateur amadeus
{ config, lib, pkgs, ... }:

{
  # Secret SSH GitHub (déchiffré par agenix dans /run/agenix/)
  age.secrets.ssh-key-github = {
    file = ../secrets/ssh-key-github.age;
    owner = "amadeus";
    group = "users";
    mode = "600";
  };

  # User amadeus
  users.users.amadeus = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    shell = pkgs.fish;
    hashedPassword = "$6$4lwIy7ta1iGgyx4I$jRmHGa7TBkG4DlHJRRp2fnkg5OlCVrPlokmm1nYWsMtnAcZS.mfBo1i6JqpWcK0.MhAkRaCdy9hlVuAnsDhBb1";
    openssh.authorizedKeys.keys = [
      # Ta clé SSH publique (à ajouter)
      # "ssh-ed25519 AAAA... amadeus@mac"
    ];
  };

  # Home Manager config
  home-manager.backupFileExtension = "backup";

  # Home Manager pour amadeus
  home-manager.users.amadeus = { pkgs, ... }: {
    home.stateVersion = "25.11";

    # Packages utilisateur
    home.packages = with pkgs; [
      eza bat fd ripgrep fzf zoxide btop dust duf lazygit jq yq
      kubectl k9s kubernetes-helm kubeseal
    ];

    # Fish shell
    programs.fish = {
      enable = true;
      shellAliases = {
        ls = "eza --icons --group-directories-first";
        ll = "eza --icons --group-directories-first -la";
        lt = "eza --icons --group-directories-first --tree --level=2";
        cat = "bat";
        find = "fd";
        grep = "rg";
        top = "btop";
        du = "dust";
        df = "duf";
        k = "kubectl";
        kgp = "kubectl get pods";
        kgs = "kubectl get services";
        kga = "kubectl get all";
        kd = "kubectl describe";
        kl = "kubectl logs";
        g = "git";
        gs = "git status";
        ga = "git add";
        gc = "git commit";
        gp = "git push";
        gpl = "git pull";
        gd = "git diff";
        gl = "git log --oneline --graph --decorate";
        lg = "lazygit";
      };
      interactiveShellInit = ''
        set -g fish_greeting
        set -gx KUBECONFIG /etc/rancher/k3s/k3s.yaml
        set -gx EDITOR vim

        # Tide configuration (joli prompt)
        set -g _tide_left_items os pwd git newline character
        set -g _tide_right_items status cmd_duration context jobs node python virtual_env
        set -g tide_git_icon
        set -g tide_os_icon
        set -g tide_pwd_icon
        set -g tide_pwd_icon_home

        # ===========================================
        # Fonctions K3s/Kubernetes pratiques
        # ===========================================

        # --- Informations & Debug ---

        # Voir tous les pods avec leur node et status
        function kpods
          kubectl get pods -A -o wide $argv
        end

        # Pods qui ne sont pas Running/Completed
        function kproblems
          kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
        end

        # Voir les événements récents (debug)
        function kevents
          set -l ns $argv[1]
          if test -z "$ns"
            kubectl get events -A --sort-by='.lastTimestamp' | tail -30
          else
            kubectl get events -n $ns --sort-by='.lastTimestamp' | tail -30
          end
        end

        # Logs d'un pod avec follow
        function klf
          kubectl logs -f $argv
        end

        # Logs des pods précédents (crashed)
        function klp
          kubectl logs --previous $argv
        end

        # Exec dans un pod (shell interactif)
        function kexec
          kubectl exec -it $argv -- sh
        end

        # Top pods (CPU/Memory)
        function ktop
          kubectl top pods -A --sort-by=memory
        end

        # Top nodes
        function knodes
          kubectl top nodes
        end

        # --- Namespaces ---

        # Lister les namespaces
        function kns
          kubectl get ns
        end

        # Changer de namespace par défaut
        function kuse
          kubectl config set-context --current --namespace=$argv[1]
          echo "Namespace changé vers: $argv[1]"
        end

        # --- Images & Conteneurs ---

        # Prune des images non utilisées (containerd/crictl)
        function kprune
          echo "⚠️  Suppression des images non utilisées..."
          sudo crictl rmi --prune
          echo "✓ Prune terminé"
        end

        # Lister les images sur le node
        function kimages
          sudo crictl images $argv
        end

        # Forcer le repull d'une image (supprimer du cache)
        function krepull
          if test -z "$argv[1]"
            echo "Usage: krepull <image:tag>"
            return 1
          end
          echo "⚠️  Suppression de l'image $argv[1] du cache..."
          sudo crictl rmi $argv[1]
          echo "✓ Image supprimée. Le prochain pod la re-pullera."
        end

        # --- Restart & Rollout ---

        # Restart un deployment (safe)
        function krestart
          if test -z "$argv[1]" -o -z "$argv[2]"
            echo "Usage: krestart <namespace> <deployment>"
            return 1
          end
          kubectl rollout restart deployment/$argv[2] -n $argv[1]
          kubectl rollout status deployment/$argv[2] -n $argv[1]
        end

        # --- COMMANDES DANGEREUSES (avec confirmation) ---

        # Supprimer un pod (force recreate)
        function kdelpod
          if test -z "$argv[1]"
            echo "Usage: kdelpod <pod-name> [-n namespace]"
            return 1
          end
          echo "⚠️  ATTENTION: Supprimer le pod $argv[1] ?"
          echo "   (Les données dans le pod seront perdues, PVC préservé)"
          read -P "Confirmer ? [y/N] " confirm
          if test "$confirm" = "y" -o "$confirm" = "Y"
            kubectl delete pod $argv
            echo "✓ Pod supprimé"
          else
            echo "Annulé"
          end
        end

        # Supprimer un namespace (TRÈS DANGEREUX)
        function kdelns
          if test -z "$argv[1]"
            echo "Usage: kdelns <namespace>"
            return 1
          end
          echo ""
          echo "🚨 DANGER: Supprimer le namespace '$argv[1]' ?"
          echo "   CELA VA SUPPRIMER:"
          echo "   - Tous les pods"
          echo "   - Tous les services"
          echo "   - Tous les PVCs (DONNÉES PERDUES !)"
          echo "   - Tous les secrets"
          echo ""
          kubectl get all -n $argv[1]
          echo ""
          read -P "Taper le nom du namespace pour confirmer: " confirm
          if test "$confirm" = "$argv[1]"
            kubectl delete namespace $argv[1]
            echo "✓ Namespace supprimé"
          else
            echo "Annulé (confirmation incorrecte)"
          end
        end

        # Scale à 0 (arrêter une app)
        function kstop
          if test -z "$argv[1]" -o -z "$argv[2]"
            echo "Usage: kstop <namespace> <deployment>"
            return 1
          end
          echo "⚠️  Arrêt de $argv[2] dans $argv[1]..."
          kubectl scale deployment/$argv[2] -n $argv[1] --replicas=0
          echo "✓ Deployment arrêté (replicas=0)"
        end

        # Scale à 1 (redémarrer une app)
        function kstart
          if test -z "$argv[1]" -o -z "$argv[2]"
            echo "Usage: kstart <namespace> <deployment>"
            return 1
          end
          kubectl scale deployment/$argv[2] -n $argv[1] --replicas=1
          echo "✓ Deployment démarré (replicas=1)"
        end

        # --- ArgoCD ---

        # Sync une app ArgoCD
        function argocd-sync
          if test -z "$argv[1]"
            echo "Usage: argocd-sync <app-name>"
            return 1
          end
          kubectl patch application $argv[1] -n argocd --type=merge -p '{"operation":{"initiatedBy":{"username":"amadeus"},"sync":{"syncStrategy":{"apply":{"force":true}}}}}'
          echo "✓ Sync déclenché pour $argv[1]"
        end

        # --- Aide ---

        function khelp
          echo "
=== Commandes K3s/Kubernetes ===

📋 INFORMATIONS
  kpods          Tous les pods (toutes namespaces)
  kproblems      Pods en erreur
  kevents [ns]   Événements récents
  ktop           Top pods (CPU/mem)
  knodes         Top nodes
  kns            Lister namespaces
  kimages        Images sur le node

🔍 DEBUG
  kl <pod>       Logs d'un pod
  klf <pod>      Logs avec follow (-f)
  klp <pod>      Logs du pod précédent (crash)
  kexec <pod>    Shell dans un pod
  kd <resource>  Describe une ressource

🔄 GESTION
  kuse <ns>           Changer de namespace
  krestart <ns> <dep> Restart un deployment
  kstart <ns> <dep>   Démarrer (scale 1)
  kstop <ns> <dep>    Arrêter (scale 0)
  kprune              Nettoyer images non utilisées
  krepull <image>     Forcer re-pull d'une image

⚠️  DANGEREUX (confirmation requise)
  kdelpod <pod>       Supprimer un pod
  kdelns <ns>         Supprimer un namespace (DANGER!)

🚀 ARGOCD
  argocd-sync <app>   Forcer sync d'une app

💡 Raccourcis de base: k, kgp, kgs, kga
"
        end
      '';
      plugins = [
        {
          name = "tide";
          src = pkgs.fishPlugins.tide.src;
        }
        {
          name = "fzf-fish";
          src = pkgs.fishPlugins.fzf-fish.src;
        }
        {
          name = "autopair";
          src = pkgs.fishPlugins.autopair.src;
        }
        {
          name = "colored-man-pages";
          src = pkgs.fishPlugins.colored-man-pages.src;
        }
      ];
    };

    # Git
    programs.git = {
      enable = true;
      settings = {
        user.name = "militu";
        user.email = "mazzeo.victor@gmail.com";
        init.defaultBranch = "main";
        core.editor = "vim";
        pull.rebase = false;
      };
    };

    # Zoxide
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    # FZF
    programs.fzf = {
      enable = true;
      enableFishIntegration = true;
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
      ];
    };

    # Starship (optionnel, alternative à Tide)
    # programs.starship.enable = true;

    # SSH config pour GitHub
    programs.ssh = {
      enable = true;
      addKeysToAgent = "yes";
      matchBlocks = {
        "*" = {
          extraOptions = {
            AddKeysToAgent = "yes";
          };
        };
        "github.com" = {
          hostname = "github.com";
          user = "git";
          identityFile = "/run/agenix/ssh-key-github";
        };
      };
    };
  };
}

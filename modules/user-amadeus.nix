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
      matchBlocks."github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "/run/agenix/ssh-key-github";
      };
    };
  };
}

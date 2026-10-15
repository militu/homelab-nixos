# Homelab NixOS

Configuration NixOS reproductible de Titan (VM Proxmox 120, `172.16.16.210`) : k3s, montages,
jobs planifiés de Jarvis.

> **Documentation** : [docs.lemasdelacolline.xyz](https://docs.lemasdelacolline.xyz), section
> Foundations › NixOS : [configuration](https://docs.lemasdelacolline.xyz/01-foundations/nixos/configuration/)
> (rôle de chaque module), [déploiement](https://docs.lemasdelacolline.xyz/01-foundations/nixos/deployment/)
> (from scratch, nixos-anywhere), [secrets](https://docs.lemasdelacolline.xyz/01-foundations/nixos/secrets/) (agenix).
> Les jobs planifiés suivent le [contrat job NixOS](https://docs.lemasdelacolline.xyz/03-operations/contrat-job-nixos/).

## Structure

```
homelab-nixos/
├── flake.nix              # Point d'entrée, définit les machines
├── hosts/                 # titan (production), nixos-test (VM de test)
├── modules/               # un module par responsabilité (table : doc « configuration »)
├── secrets/               # secrets.nix = inventaire agenix ; *.age chiffrés ; expiries.json
├── Makefile · mise.toml   # make ci : la gate, en local et en CI
└── .github/workflows/     # gate en ligne (dépôt public) et mise à jour hebdomadaire du verrou
```

## Mettre à jour Titan

- Automatique : `system.autoUpgrade` quotidien (`modules/auto-upgrade.nix`, heartbeat Gatus
  `titan_nixos-upgrade`).
- Manuel, après fusion de la PR (accord de Victor) :
  `sudo nixos-rebuild switch --flake ~/code/homelab-nixos#titan`.
- Valider avant push : `make ci` (évalue les configurations et lance les checks du flake).

## Clé hôte

La clé qui déchiffre les secrets agenix est dans Bitwarden `0-Bootstrap` → `SSH · homelab-nixos-master`
(registre, § Secrets locaux). Procédure : doc « secrets ».

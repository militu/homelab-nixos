# Homelab NixOS

Configuration NixOS reproductible pour homelab Proxmox.

## Structure

```
homelab-nixos/
├── flake.nix                    # Point d'entrée, définit les machines
├── hosts/
│   ├── nixos-test/              # VM de test
│   │   ├── configuration.nix
│   │   ├── disk-config.nix      # Partitionnement (disko)
│   │   └── hardware-configuration.nix
│   └── titan/                   # VM de production
│       ├── configuration.nix
│       ├── disk-config.nix
│       └── hardware-configuration.nix
├── modules/
│   ├── common.nix               # Config commune (boot, nix, ssh...)
│   ├── user-amadeus.nix         # Utilisateur + home-manager + fish
│   ├── k3s.nix                  # Kubernetes K3s
│   └── nfs-truenas.nix          # Montages NFS
└── secrets/
    ├── secrets.nix              # Définition des secrets (agenix)
    └── *.age                    # Secrets chiffrés
```

## Déploiement "1 clic"

### Prérequis

1. Nix installé sur ton Mac/Linux
2. Une VM Proxmox bootée sur l'ISO NixOS live

### Déployer nixos-test

```bash
# Créer la VM sur Proxmox (ou via l'interface web)
# La VM doit booter sur l'ISO NixOS et avoir une IP via DHCP

# Depuis ton Mac
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nixos-test \
  root@<IP_VM_LIVE>
```

### Déployer titan (production)

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#titan \
  root@<IP_VM_LIVE>
```

## Mise à jour d'une machine existante

```bash
# Depuis la machine NixOS
sudo nixos-rebuild switch --flake github:militu/homelab-nixos#nixos-test
```

## Secrets (agenix)

Les secrets sont chiffrés avec les clés SSH host des machines.

```bash
# Éditer un secret
cd secrets
agenix -e ssh-key-github.age

# Rechiffrer après ajout d'une nouvelle machine
agenix -r
```

## Backup de la master key

La clé host SSH (`/etc/ssh/ssh_host_ed25519_key`) doit être backupée.
Sans elle, impossible de déchiffrer les secrets sur une nouvelle installation.

Options de backup :
- 1Password / Bitwarden
- USB chiffré
- Vault HashiCorp

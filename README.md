# Homelab NixOS

Configuration NixOS 100% reproductible pour homelab Proxmox.

## Structure

```
homelab-nixos/
├── flake.nix                    # Point d'entrée, définit les machines
├── hosts/
│   ├── nixos-test/              # VM de test (172.16.16.220)
│   └── titan/                   # VM de production (172.16.16.210)
├── modules/
│   ├── common.nix               # Boot, SSH, timezone, packages de base
│   ├── user-amadeus.nix         # Utilisateur + home-manager + fish
│   ├── k3s.nix                  # Kubernetes K3s
│   └── nfs-truenas.nix          # Montages NFS vers TrueNAS
└── secrets/
    ├── secrets.nix              # Définition des secrets (agenix)
    └── ssh-key-github.age       # Clé SSH GitHub (chiffrée)
```

## Déploiement "1 clic"

### Prérequis

1. Nix installé sur ton Mac
2. La clé master (`~/.secrets/homelab/host_key`) - voir section "Clé Master"
3. Une VM Proxmox bootée sur l'ISO NixOS live

### Déployer une VM

```bash
# Préparer les fichiers à injecter (clé host)
mkdir -p /tmp/nixos-extra/etc/ssh
cp ~/.secrets/homelab/host_key /tmp/nixos-extra/etc/ssh/ssh_host_ed25519_key
chmod 600 /tmp/nixos-extra/etc/ssh/ssh_host_ed25519_key

# Déployer
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nixos-test \
  --extra-files /tmp/nixos-extra \
  root@<IP_VM_LIVE>
```

La VM aura automatiquement :
- Ta clé SSH GitHub (déchiffrée)
- Fish + Tide configuré
- K3s prêt
- Montages NFS

## Mise à jour d'une machine existante

```bash
# Depuis la machine NixOS
sudo nixos-rebuild switch --flake github:militu/homelab-nixos#nixos-test
```

## Clé Master

Une seule clé host SSH pour toutes les VMs. Elle permet de déchiffrer les secrets.

### Emplacement

```
~/.secrets/homelab/
├── host_key       # Clé privée (NE JAMAIS PARTAGER)
└── host_key.pub   # Clé publique (dans secrets.nix)
```

### Backup

**La clé privée est sauvegardée dans Bitwarden.**

Sans cette clé, impossible de :
- Déchiffrer les secrets existants
- Déployer une nouvelle VM avec les secrets

### Régénérer (si perdue)

Si tu perds la clé master, il faut :
1. Générer une nouvelle clé : `ssh-keygen -t ed25519 -f ~/.secrets/homelab/host_key -N ""`
2. Mettre à jour `secrets/secrets.nix` avec la nouvelle clé publique
3. Re-chiffrer tous les secrets : `cd secrets && agenix -r`
4. Sauvegarder la nouvelle clé dans Bitwarden

## Secrets (agenix)

Les secrets sont chiffrés avec la clé master. Seules les VMs qui ont cette clé peuvent les déchiffrer.

### Ajouter un secret

```bash
# 1. Déclarer le secret dans secrets/secrets.nix
"mon-secret.age".publicKeys = systems;

# 2. Chiffrer le secret
cd secrets
agenix -e mon-secret.age
# → Éditeur s'ouvre, coller le contenu, sauver

# 3. Configurer où le secret apparaît (dans un module .nix)
age.secrets.mon-secret.file = ../secrets/mon-secret.age;
```

### Secrets actuels

| Fichier | Description | Déchiffré vers |
|---------|-------------|----------------|
| `ssh-key-github.age` | Clé SSH privée GitHub | `~/.ssh/id_ed25519_github` |

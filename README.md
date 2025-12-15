# Homelab NixOS

Configuration NixOS 100% reproductible pour homelab Proxmox.

> **Documentation complète** : [mkdocs.lemasdelacolline.xyz](https://mkdocs.lemasdelacolline.xyz)

## Structure

```
homelab-nixos/
├── flake.nix                    # Point d'entrée, définit les machines
├── hosts/
│   ├── nixos-test/              # VM de test (172.16.16.220)
│   └── titan/                   # VM de production (172.16.16.210)
├── modules/
│   ├── common.nix               # Boot, SSH, timezone, packages de base
│   ├── user-amadeus.nix         # Utilisateur + home-manager + agenix secrets
│   ├── k3s.nix                  # Kubernetes K3s
│   ├── k3s-repo.nix             # Clone auto du repo k3s-homelab
│   ├── nfs-truenas.nix          # Montages NFS vers TrueNAS
│   ├── frigate-storage.nix      # mergerfs SSD+NAS + frigate-sync + cron
│   ├── cifs-mac.nix             # Montages CIFS Mac via Tailscale
│   └── gpu-amd.nix              # GPU AMD passthrough (ROCm, amdgpu)
└── secrets/
    ├── secrets.nix              # Définition des secrets (agenix)
    ├── ssh-key-github.age       # Clé SSH GitHub (chiffrée)
    └── cifs-mac.age             # Credentials CIFS Mac (chiffrés)
```

## Déploiement from scratch

### 1. Créer la VM sur Proxmox

```bash
# Production (titan) - 32GB RAM, 8 cores, 200GB disk
qm create 120 --name titan-nixos --memory 32768 --cores 8 --cpu host \
  --bios ovmf --machine q35 \
  --efidisk0 local-lvm:1,efitype=4m \
  --scsi0 local-lvm:200,ssd=1,discard=on,cache=writeback,iothread=1 \
  --scsi1 local:iso/nixos-25.11-minimal.iso,media=cdrom \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr0,tag=10,firewall=1 \
  --balloon 0 \
  --onboot 1 \
  --boot order=scsi1 \
  --agent 1

# Test (nixos-test) - 4GB RAM, 2 cores, 32GB disk
qm create 110 \
  --name nixos-test \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --bios ovmf \
  --machine q35 \
  --efidisk0 local-lvm:1,efitype=4m \
  --scsi0 local-lvm:32,ssd=1,discard=on \
  --scsi1 local:iso/nixos-25.11-minimal.iso,media=cdrom \
  --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr0,tag=10 \
  --boot order=scsi1 \
  --agent 1
```

### 2. Démarrer la VM et configurer SSH

```bash
# Démarrer la VM
qm start 110

# Dans la console Proxmox de la VM:
sudo -i
passwd     # Définir un mot de passe temporaire pour root
ip a       # Noter l'IP (DHCP)
```

### 3. Préparer la clé master sur ton Mac

```bash
# Récupérer la clé master depuis Bitwarden → "NixOS Homelab Master Key"
mkdir -p ~/.secrets/homelab
# Coller le contenu de la clé privée dans ~/.secrets/homelab/host_key
chmod 600 ~/.secrets/homelab/host_key

# Préparer les extra-files pour nixos-anywhere
mkdir -p /tmp/extra-files/etc/ssh
cp ~/.secrets/homelab/host_key /tmp/extra-files/etc/ssh/ssh_host_ed25519_key
chmod 600 /tmp/extra-files/etc/ssh/ssh_host_ed25519_key
```

### 4. Déployer avec nixos-anywhere

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake github:militu/homelab-nixos#titan \
  --extra-files /tmp/extra-files \
  root@<IP_VM>
```

### 5. Configurer le boot et retirer l'ISO

```bash
# Après le reboot automatique, retirer l'ISO
qm stop 120
qm set 120 --delete scsi1
qm set 120 --boot order=scsi0

# (Optionnel) Ajouter GPU AMD passthrough
qm set 120 -hostpci0 0000:04:00.0,romfile=vbios_1002.bin,x-vga=1

qm start 120
```

### 6. Post-installation

```bash
# Se connecter
ssh amadeus@172.16.16.220

# Configurer Tide (prompt Fish joli)
tide configure
```

## Mise à jour d'une machine existante

```bash
# Depuis la machine NixOS
sudo nixos-rebuild switch --flake github:militu/homelab-nixos#nixos-test

# Avec refresh du cache (si changements récents)
sudo nixos-rebuild switch --flake github:militu/homelab-nixos#nixos-test --refresh
```

## Secrets dans Bitwarden

Tous les secrets sont sauvegardés dans Bitwarden:

| Item Bitwarden             | Description                      | Usage                             |
| -------------------------- | -------------------------------- | --------------------------------- |
| NixOS Homelab Master Key   | Clé SSH host master              | Déchiffre tous les secrets agenix |
| NixOS GitHub SSH Key       | Clé SSH GitHub (sans passphrase) | Clone repos privés                |
| NixOS CIFS Mac Credentials | username/password Mac shares     | Montages CIFS                     |

### Format des credentials CIFS

```
username=<CIFS_USERNAME>
password=<CIFS_PASSWORD>
```

## Gestion des secrets (agenix)

### Déchiffrer un secret (vérification)

```bash
cd ~/code/homelab-nixos/secrets
nix run github:ryantm/agenix -- -d ssh-key-github.age -i ~/.secrets/homelab/host_key
```

### Modifier/Ajouter un secret

```bash
cd ~/code/homelab-nixos/secrets

# Éditer un secret existant
nix run github:ryantm/agenix -- -e ssh-key-github.age -i ~/.secrets/homelab/host_key

# Ou créer depuis un fichier
echo "contenu" | nix run github:ryantm/agenix -- -e nouveau-secret.age -i ~/.secrets/homelab/host_key
```

### Re-chiffrer tous les secrets (si clé master change)

```bash
cd ~/code/homelab-nixos/secrets
nix run github:ryantm/agenix -- -r -i ~/.secrets/homelab/host_key
```

## Ce qui est automatisé au déploiement

- Secrets déchiffrés (SSH GitHub, CIFS)
- Clone du repo k3s-homelab dans `/home/amadeus/k3s`
- K3s installé et démarré
- Mounts NFS TrueNAS (automount)
- Mounts CIFS Mac (automount via Tailscale)
- mergerfs `/mnt/frigate_union` (SSD + NAS)
- Cron frigate-sync à 1h du matin
- Fish + plugins (Tide, fzf, autopair)
- GPU AMD (amdgpu + ROCm) si module activé

## Démarrer la stack K3s

Une fois connecté sur titan NixOS, le repo k3s est cloné automatiquement :

```bash
cd ~/k3s

# Configurer kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Vérifier que K3s tourne
kubectl get nodes

# Déployer ArgoCD (gère ensuite les autres apps via GitOps)
kubectl apply -f apps/argocd/

# Voir les pods
kubectl get pods -A
```

### Troubleshooting K3s

Si K3s ne démarre pas après un premier déploiement (token corrompu) :

```bash
# Vérifier le status
sudo systemctl status k3s
sudo journalctl -u k3s --no-pager -n 30

# Si erreur "failed to normalize server token", reset K3s :
sudo systemctl stop k3s
sudo rm -rf /var/lib/rancher/k3s/server
sudo systemctl start k3s
sleep 15
sudo systemctl status k3s
```

## Checklist migration finale

- [ ] Arrêter l'ancien titan (VM 100) : `qm stop 100`
- [ ] Créer la VM titan-nixos (120) avec la commande ci-dessus
- [ ] Démarrer et noter l'IP DHCP : `qm start 120`
- [ ] Configurer SSH : `sudo -i && passwd && ip a`
- [ ] Déployer : `nix run github:nix-community/nixos-anywhere -- --flake github:militu/homelab-nixos#titan --extra-files /tmp/extra-files root@<IP_DHCP>`
- [ ] Finaliser boot : `qm stop 120 && qm set 120 --delete scsi1 --boot order=scsi0 && qm set 120 -hostpci0 0000:04:00.0,romfile=vbios_1002.bin,x-vga=1 && qm start 120`
- [ ] Vérifier : `ssh amadeus@172.16.16.210` puis `kubectl get nodes`
- [ ] Démarrer K3s stack : `cd ~/k3s && kubectl apply -f apps/argocd/`
- [ ] Supprimer l'ancien titan : `qm destroy 100`

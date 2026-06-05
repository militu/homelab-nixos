# Agenix secrets configuration
# Les clés publiques des machines qui peuvent déchiffrer les secrets

let
  # Clé host master - utilisée par toutes les VMs homelab
  homelab-master = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPldplL5GA23XYflnquuwXFKioimTPZ49v5E8tmjnl2";

  # Toutes les machines utilisent la même clé
  systems = [ homelab-master ];
in
{
  # Clé SSH privée pour GitHub
  "ssh-key-github.age".publicKeys = systems;

  # Credentials CIFS pour les shares Mac
  "cifs-mac.age".publicKeys = systems;

  # Clé AES-256 (base64) partagée avec l'extension navigateur "Qonto Cookie → Jarvis"
  # pour déchiffrer le cookie qonto_session transmis chiffré par mail.
  "jarvis-qonto-key.age".publicKeys = systems;

  # Mot de passe utilisateur (optionnel, on utilise hashedPassword pour l'instant)
  # "amadeus-password.age".publicKeys = systems;
}

# Agenix secrets configuration
# Les clés publiques des machines qui peuvent déchiffrer les secrets

let
  # Clé host de nixos-test (à mettre à jour avec ta vraie clé)
  nixos-test = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGUt1Gc0ZJW9JwPFabixzZvsRVTSvqsliJtbCH64BWv/";

  # Clé host de titan (à ajouter quand tu migreras)
  # titan = "ssh-ed25519 AAAA...";

  # Toutes les machines
  systems = [ nixos-test ];

  # Ta clé SSH personnelle (pour chiffrer depuis ton Mac)
  # amadeus = "ssh-ed25519 AAAA...";
  # users = [ amadeus ];
in
{
  # Clé SSH privée pour GitHub
  "ssh-key-github.age".publicKeys = systems;

  # Mot de passe utilisateur (optionnel, on utilise hashedPassword pour l'instant)
  # "amadeus-password.age".publicKeys = systems;
}

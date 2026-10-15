# sudo validé par Touch ID sur le Mac (clé Secretive transmise par ssh -A).
# Le mot de passe reste le secours : console, Mac absent, agent non transmis.
{ ... }:

{
  security.pam.sshAgentAuth = {
    enable = true;
    # Fichier dédié, détenu par root : ne jamais y mettre homelab-master,
    # qui existe en fichier sur le Mac et signerait sans Touch ID.
    authorizedKeysFiles = [ "/etc/ssh/sudo_authorized_keys" ];
  };
  security.pam.services.sudo.sshAgentAuth = true;

  # Clé Secretive du Mac (commodité, hors PRA : régénérable, mot de passe en secours).
  environment.etc."ssh/sudo_authorized_keys" = {
    mode = "0444";
    text = ''
      ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBN/X0kFsp3+DgbEao8soOIKZebn6swJShZJ4LYljDttDDzK4StMG3ofeXmrPufH9dRLcukqgNf0SCsZlC+RSzXA= titan-sudo@secretive
    '';
  };
}

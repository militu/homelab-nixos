# GPU AMD passthrough support (ROCm pour Frigate/Immich)
{ config, lib, pkgs, ... }:

{
  # Activer le driver AMD
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Graphics support (RADV est activé par défaut)
  hardware.graphics.enable = true;

  # ROCm pour ML/compute
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];

  # Outils de diagnostic
  environment.systemPackages = with pkgs; [
    pciutils
    libva-utils  # vainfo
    rocmPackages.rocminfo
  ];
}

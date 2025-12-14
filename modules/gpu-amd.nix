# GPU AMD passthrough support (ROCm pour Frigate/Immich)
{ config, lib, pkgs, ... }:

{
  # Activer le driver AMD
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Graphics support
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      amdvlk
      rocmPackages.clr.icd
    ];
  };

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

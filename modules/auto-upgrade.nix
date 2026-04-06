# Automatic system upgrades, garbage collection & store optimization
{ config, lib, pkgs, ... }:

{
  # Auto-upgrade: pull config from GitHub and rebuild
  # flake.lock updates are handled via GitHub Actions (nix flake update + PR)
  system.autoUpgrade = {
    enable = true;
    flake = "github:militu/homelab-nixos#titan";
    dates = "*-*-* 04:00:00";
    randomizedDelaySec = "30min";
    allowReboot = false;
    operation = "switch";
  };

  # Garbage collection - remove generations older than 30 days
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Store optimization (hard-link identical files, ~25-35% space saved)
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };
}

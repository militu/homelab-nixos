{
  description = "NixOS Homelab - Configuration reproductible";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, agenix, ... }: {
    nixosConfigurations = {
      # VM de test
      nixos-test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          ./hosts/nixos-test/configuration.nix
          {
            environment.systemPackages = [ agenix.packages.x86_64-linux.default ];
          }
        ];
      };

      # VM de production (future migration)
      titan = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          ./hosts/titan/configuration.nix
          {
            environment.systemPackages = [ agenix.packages.x86_64-linux.default ];
          }
        ];
      };
    };
  };
}

{
  description = "Skylab's nix config files";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:nixos/nixos-hardware";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    helix-git = {
      url = "github:helix-editor/helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-cosmic = {
      url = "github:lilyinstarlight/nixos-cosmic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin.url = "github:catppuccin/nix";
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = import ./src/overlays {
          inherit inputs;
          path = ./src/overlays;
        };
      };
      home-manager-path = "~/.config/nixfiles";
      username = "skylab";
      hc = config:
        home-manager.lib.homeManagerConfiguration (config // {
          inherit pkgs;
          modules = [ inputs.agenix.homeManagerModules.default ]
            ++ config.modules;
        });
    in
    {
      nixosConfigurations.jupiter = nixpkgs.lib.nixosSystem
        {
          system = "x86_64-linux";
          modules = [
            inputs.catppuccin.nixosModules.catppuccin
            inputs.nixos-hardware.nixosModules.common-cpu-intel
            # inputs.nixos-hardware.nixosModules.common-gpu-intel
            inputs.nixos-hardware.nixosModules.common-gpu-nvidia
            inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
            inputs.nixos-hardware.nixosModules.system76
            inputs.nixos-cosmic.nixosModules.default
            ./src/systems/jupiter.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users."${username}" = import (./src/homes + "/${username}.nix") {
                  inherit pkgs;
                  inherit username;
                  inherit inputs;
                  inherit home-manager-path;
                };
              };
            }
          ];
        };
    };
}

{
  description = "Skylab's nix config files";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgsUnstable.url = "github:nixos/nixpkgs/nixos-unstable";
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
    nixgl = {
      url = "github:guibou/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helix-git = {
      url = "github:helix-editor/helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # copilot-lsp-src = {
    #   url = "github:github/copilot.vim";
    #   flake = false;
    # };
    bottom-theme = {
      url = "github:catppuccin/bottom";
      flake = false;
    };
    bat-theme = {
      url = "github:catppuccin/bat";
      flake = false;
    };
    nnn = {
      url = "github:jarun/nnn";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, nixpkgsUnstable, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = (import ./src/overlays {
          inherit inputs;
          path = ./src/overlays;
          #}) ++ [ inputs.nixgl.overlay ];
        });
      };
      pkgsUnstable = import nixpkgsUnstable {
        inherit system;
        config.allowUnfree = true;
        overlays = (import ./src/overlays {
          inherit inputs;
          path = ./src/overlays;
          #}) ++ [ inputs.nixgl.overlay ];
        });
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
            inputs.nixos-hardware.nixosModules.common-cpu-intel
            inputs.nixos-hardware.nixosModules.common-gpu-intel
            inputs.nixos-hardware.nixosModules.common-gpu-nvidia
            inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
            inputs.nixos-hardware.nixosModules.system76
            ./src/systems/jupiter.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users."${username}" = import ./home.nix {
                inherit pkgs;
                inherit pkgsUnstable;
                inherit username;
                inherit inputs;
                inherit home-manager-path;
              };
            }
          ];
        };
    };
}

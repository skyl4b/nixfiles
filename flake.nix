{
  description = "Skylab's nix config files";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:nixos/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ ... }:
    let
      mkHost = import ./src/lib/mk-host.nix { inherit inputs; };
      mkUser = import ./src/lib/mk-user.nix;
      skylab = { config, lib, ... }: mkUser {
        name = "skylab";
        profile = "complete";
        description = "Eduardo Farinati Leite";
        homeStateVersion = "23.11";
        homeModules = [ ./src/modules/home/keyboard.nix ];
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAknKoOCh4U3ZQK839e+i29Ae79hTbhoGlqPrmAjDBwd"
        ];
        extraGroups = [ "wheel" "networkmanager" "adm" ]
          ++ lib.optional config.virtualisation.docker.enable "docker"
          ++ lib.optionals config.virtualisation.libvirtd.enable [ "kvm" "libvirtd" ]
          ++ [ "video" ];
      };
    in
    {
      nixosConfigurations = {
        jupiter = mkHost {
          hostName = "jupiter";
          users = [ skylab ];
          hardwareModules = with inputs.nixos-hardware.nixosModules; [
            common-cpu-intel
            common-gpu-nvidia
            common-pc-laptop-ssd
            system76
          ];
        };
        mars = mkHost {
          hostName = "mars";
          users = [ skylab ];
          hardwareModules = with inputs.nixos-hardware.nixosModules; [
            common-cpu-amd
            common-gpu-nvidia
            common-pc-laptop-ssd
          ];
        };
        moon = mkHost {
          hostName = "moon";
          users = [ skylab ];
          hardwareModules = with inputs.nixos-hardware.nixosModules; [
            common-cpu-intel-cpu-only
            common-pc-laptop
          ];
        };
      };
    };
}

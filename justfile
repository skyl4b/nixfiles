#!/usr/bin/env -S just --justfile

# Choose the recipe to run interactively
_default:
    -@just --choose

# Update nix flake revision for every input
nix:
    nix flake update

# Switch to the new NixOS configuration
switch:
    sudo nixos-rebuild switch

# Update flatpak apps
flatpak:
    flatpak update

# Update all packages
update-all: flatpak nix switch

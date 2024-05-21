#!/usr/bin/env -S just --justfile

# Choose the recipe to run interactively
default:
    @just --choose

# Update nix flake revision for every input
update:
    nix flake update

# Switch to the new NixOS configuration
switch:
    sudo nixos-rebuild switch

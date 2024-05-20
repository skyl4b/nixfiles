#!/usr/bin/env -S just --justfile

# Update nix flake revision for every input
flake-bump:
    nix flake update

# Switch to the new NixOS configuration
nixos-switch:
    sudo nixos-rebuild switch

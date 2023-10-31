{ inputs, path, ... }:

final: prev: {
  copilot-lsp = import (path + "/../packages/copilot-lsp.nix") {
    pkgs = prev;
    copilot-lsp-src = inputs.copilot-lsp-src;
  };
}

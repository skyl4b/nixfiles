{ inputs }:

final: prev: {
  copilot-lsp = import ../packages/copilot-lsp.nix {
    pkgs = prev;
    copilot-lsp-src = inputs.copilot-lsp-src;
  };
}

{ pkgs, copilot-lsp-src, ... }:

pkgs.stdenv.mkDerivation {
  pname = "copilot-lsp";
  version = "1.0.0";
  src = copilot-lsp-src;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out
    cp -r $src/dist/* $out/
    mkdir -p $out/bin
    makeWrapper '${pkgs.nodejs}/bin/node' "$out/bin/copilot" \
      --add-flags "$out/agent.js"
  '';
}

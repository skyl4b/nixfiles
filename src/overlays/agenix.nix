{ inputs, ... }:

final: _prev: {
  agenix = inputs.agenix.packages.${final.stdenv.hostPlatform.system}.default;
}

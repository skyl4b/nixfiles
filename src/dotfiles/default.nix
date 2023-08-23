{ inputs }:

let
  utils = import ../utils.nix { inherit inputs; };
in
  utils.importDir ./.

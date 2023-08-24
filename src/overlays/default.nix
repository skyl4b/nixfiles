args:

let utils = import ../utils.nix args;
in builtins.attrValues (utils.importDir ./.)

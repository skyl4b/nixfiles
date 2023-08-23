{ inputs }:

with builtins; rec {
  take = n: lst:
    if n <= 0 then [ ] else [ head lst ] ++ (take (n - 1) (tail lst));

  removeSuffix = suffix: str:
    let
      suffixLen = stringLength suffix;
      len = stringLength str;
    in if suffixLen <= len && suffix
    == substring (len - suffixLen) suffixLen str then
      substring 0 (len - suffixLen) str
    else
      str;

  filterDefault = files:
    builtins.filter (file: file != "default.nix") (attrNames files);

  importDir = dir:
    listToAttrs (map (file: {
      name = removeSuffix ".nix" (baseNameOf file);
      value = import (dir + "/${file}") { inherit inputs; };
    }) (filterDefault (readDir dir)));
}

args:

with builtins; rec {
  take = n: lst:
    if n <= 0 then [ ] else [ head lst ] ++ (take (n - 1) (tail lst));

  removeSuffix = suffix: str:
    let
      suffixLen = stringLength suffix;
      len = stringLength str;
    in
    if suffixLen <= len && suffix
      == substring (len - suffixLen) suffixLen str then
      substring 0 (len - suffixLen) str
    else
      str;

  # Filters default.nix from a set
  filterDefault = files: filter (file: file != "default.nix") (attrNames files);

  importDir = dir:
    let
      rawEntries = readDir dir;
      validEntries = filter
        (entry:
          let
            fullPath = "${dir}/${entry}";
            # Filters files with the .nix extension or directories
            # with default.nix files
          in
          ((rawEntries.${entry} != "directory" && (removeSuffix ".nix" entry)
            != entry) || pathExists "${fullPath}/default.nix"))
        (filterDefault rawEntries);
    in
    listToAttrs (map
      (entry: {
        name = removeSuffix ".nix" (baseNameOf entry);
        value = import ("${dir}/${entry}") args;
      })
      validEntries);
}

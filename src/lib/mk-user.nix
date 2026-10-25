{ name
, profile ? "minimal"
, description ? name
, homeDirectory ? "/home/${name}"
# Preserve existing homes; new installations should choose their initial version.
, homeStateVersion ? "23.11"
, extraGroups ? [ ]
, authorizedKeys ? [ ]
, hashedPasswordFile ? null
, homeModules ? [ ]
}:

{
  users.users.${name} = {
    isNormalUser = true;
    inherit description extraGroups;
    home = homeDirectory;
    openssh.authorizedKeys.keys = authorizedKeys;
  } // (if hashedPasswordFile == null then { } else { inherit hashedPasswordFile; });

  home-manager.users.${name} = { pkgs, ... }: {
    imports = [ ../home ] ++ homeModules;

    home = {
      username = name;
      inherit homeDirectory;
      stateVersion = homeStateVersion;
      packages = import (../home/profiles + "/${profile}.nix") { inherit pkgs; };
    };
  };
}

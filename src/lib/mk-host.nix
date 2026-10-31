{ inputs }:

{ hostName, system ? "x86_64-linux", users, hardwareModules ? [ ] }:

inputs.nixpkgs.lib.nixosSystem {
  specialArgs = { inherit inputs; };

  modules = hardwareModules ++ [
    (../hosts + "/${hostName}")
    inputs.home-manager.nixosModules.home-manager
    {
      networking.hostName = hostName;
      nixpkgs.hostPlatform = system;
      nixpkgs.overlays = import ../overlays { inherit inputs; };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = { inherit inputs; };
      };

      # useUserPackages puts Home Manager's environment helper in this profile.
      # Load it without requiring Home Manager to own the user's shell files.
      environment.extraInit = ''
        if [ -r "/etc/profiles/per-user/''${USER:-}/etc/profile.d/hm-session-vars.sh" ]; then
          . "/etc/profiles/per-user/''${USER:-}/etc/profile.d/hm-session-vars.sh"
        fi
      '';
    }
  ] ++ users;
}

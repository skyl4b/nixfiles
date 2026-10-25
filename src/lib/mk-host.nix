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
    }
  ] ++ users;
}

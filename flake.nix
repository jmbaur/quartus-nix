{
  description = "quartus-nix";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = inputs: {
    overlays.default =
      final: prev:
      builtins.listToAttrs (
        map (_source: {
          name = "quartus-pro-programmer-${
            builtins.replaceStrings [ "." ] [ "_" ] (prev.lib.versions.majorMinor _source.version)
          }";
          value = prev.callPackage ./package.nix { inherit _source; };
        }) (import ./sources.nix)
      )
      // {
        quartus-pro-programmer = final.quartus-pro-programmer-25_1;
      };

    nixosModules.default =
      { config, lib, ... }:
      {
        imports = [ ./module.nix ];
        nixpkgs.overlays = [ inputs.self.overlays.default ];
      };

    legacyPackages = inputs.nixpkgs.lib.genAttrs [ "x86_64-linux" ] (
      system:
      import inputs.nixpkgs {
        inherit system;
        overlays = [ inputs.self.overlays.default ];
      }
    );
  };
}

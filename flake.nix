{
  description = "quartus-nix";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = inputs: {
    overlays.default =
      final: prev:
      let
        inherit (prev.lib)
          flatten
          foldl
          listToAttrs
          mapAttrsToList
          replaceStrings
          versionOlder
          versions
          ;
      in
      {
        makeQuartus = prev.callPackage ./package.nix { };
      }
      // listToAttrs (
        flatten (
          mapAttrsToList (
            package: sources:
            (map (source: {
              name = "${package}-${replaceStrings [ "." ] [ "_" ] (versions.majorMinor source.version)}";
              value = final.makeQuartus {
                pname = package;
                inherit (source) version;
                inherit source;
              };
            }) sources)
            # Add an alias to the latest version, suffixed with "-latest"
            ++ (
              let
                source = foldl (a: b: if versionOlder a.version b.version then b else a) {
                  version = "0";
                } sources;
              in
              [
                {
                  name = "${package}-latest";
                  value = final.makeQuartus {
                    pname = package;
                    inherit (source) version;
                    inherit source;
                  };
                }
              ]
            )
          ) (import ./sources.nix)
        )
      );

    nixosModules.default = {
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

{
  description = "quartus-nix";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };
  };
  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;

      quartusPackages = lib.flatten (
        lib.mapAttrsToList (
          pname:
          { hasCompiler, sources }:
          (map (source: {
            attrName = "${pname}-${
              lib.replaceStrings [ "." ] [ "_" ] (lib.versions.majorMinor source.version)
            }";
            inherit pname hasCompiler source;
          }) sources)
          # Add an alias to the latest version, suffixed with "-latest"
          ++ [
            {
              attrName = "${pname}-latest";
              inherit pname hasCompiler;
              source = lib.foldl (a: b: if lib.versionOlder a.version b.version then b else a) {
                version = "0";
              } sources;
            }
          ]
        ) (import ./sources.nix)
      );
    in
    {
      overlays.default =
        final: prev:
        {
          makeQuartus = prev.callPackage ./package.nix { };
        }
        // lib.listToAttrs (
          map (
            {
              attrName,
              pname,
              hasCompiler,
              source,
            }:
            lib.nameValuePair attrName (
              final.makeQuartus {
                inherit pname hasCompiler source;
                inherit (source) version;
              }
            )
          ) quartusPackages
        );

      nixosModules.default.imports = [ ./module.nix ];

      legacyPackages = lib.genAttrs [ "x86_64-linux" ] (
        system:
        import inputs.nixpkgs {
          inherit system;
          overlays = [ inputs.self.overlays.default ];
        }
      );

      checks = lib.genAttrs [ "x86_64-linux" ] (
        system:
        let
          pkgs = inputs.self.legacyPackages.${system};
        in
        lib.listToAttrs (
          map (
            { attrName, ... }:
            lib.nameValuePair "${attrName}-smoke-test" (
              pkgs.callPackage ./tests/smoke-test.nix { quartus = pkgs.${attrName}; }
            )
          ) (lib.filter ({ hasCompiler, ... }: hasCompiler) quartusPackages)
        )
      );
    };
}

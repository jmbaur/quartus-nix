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
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        options.programs.quartus-pro-programmer = {
          enable = lib.mkEnableOption "quartus-pro-programmer";
          package = lib.mkPackageOption pkgs "quartus-pro-programmer" { };
        };

        config = lib.mkIf config.programs.quartus-pro-programmer.enable {
          nixpkgs.overlays = [ inputs.self.overlays.default ];
          environment.systemPackages = [ config.programs.quartus-pro-programmer.package ];
          environment.profileRelativeSessionVariables.PATH = [ "/qprogrammer/quartus/bin" ];
          environment.pathsToLink = [ "/qprogrammer" ];
        };
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

{
  description = "quartus-nix";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = inputs: {
    overlays.default = final: prev: {
      quartus-pro-programmer = final.callPackage ./package.nix { };
    };
    nixosModules.default =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        options.programs.quartus-pro-programmer.enable = lib.mkEnableOption "quartus-pro-programmer";
        config = lib.mkIf config.programs.quartus-pro-programmer.enable {
          nixpkgs.overlays = [ inputs.self.overlays.default ];
          environment.systemPackages = [ pkgs.quartus-pro-programmer ];
          environment.profileRelativeSessionVariables.PATH = [ "/qprogrammer/quartus/bin" ];
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

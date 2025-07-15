{
  description = "quartus-nix";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = inputs: {
    overlays.default = final: prev: {
      quartus-pro-programmer = final.callPackage ./package.nix { };
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

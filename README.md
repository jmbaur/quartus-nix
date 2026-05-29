# quartus-nix

Altera Quartus, packaged with Nix.

## Usage

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    quartus-nix.url = "github:jmbaur/quartus-nix";
    # Optional, if you want quartus-nix to use the same nixpkgs input:
    # quartus-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, quartus-nix, ... }@inputs: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        ./configuration.nix
        quartus-nix.nixosModules.default
        ({ pkgs, ... }: {
          # Optional, but needed if you want to select a quartus-pro-programmer other than the latest
          nixpkgs.overlays = [
          	quartus-nix.overlays.default
          ];
          
          programs.quartus-pro-programmer = {
          	enable = true;
          
          	# Optional: start jtagd as a system service.
          	jtagd.enable = true;
          
          	# Optional: choose a version from the overlay instead of the module default.
          	# Available examples include:
          	# - pkgs.quartus-pro-programmer-latest
          	# - pkgs.quartus-pro-programmer-26_1
          	# - pkgs.quartus-pro-programmer-25_3
          	# package = pkgs.quartus-pro-programmer-26_1;
          };
        })
      ];
    };
  };
}
```

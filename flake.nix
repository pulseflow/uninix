{
  description = "universal nix: plug-n-play nix with build tooling";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    parts.url = "github:hercules-ci/flake-parts";
    parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nix-unit.url = "github:adisbladis/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    nix-unit.inputs.flake-parts.follows = "parts";
  };

  outputs = inputs @ { self, nixpkgs, parts }:
    let
      base = nixpkgs.lib // builtins;
      perSystem = { self', pkgs, system, inputs', ... }: {

      };
    in parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./modules/flake-parts/all-modules.nix
        ./modules/uninix-utils/flake-module.nix
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      inherit perSystem;
    };
}

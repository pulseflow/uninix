{
  description = "universal nix: plug-n-play nix with build tooling";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    parts.url = "github:hercules-ci/flake-parts";
    parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    commit.url = "github:cachix/pre-commit-hooks.nix";
    commit.inputs.nixpkgs.follows = "nixpkgs";

    # used to bootstrap uninix, not meant to be packaged
    crane.url = "github:ipetkov/crane";
    crane.inputs.nixpkgs.follows = "nixpkgs";

    rust.url = "github:oxalica/rust-overlay";
    rust.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, parts, commit, crane, rust, ... } @ proxy:
    let
      base = nixpkgs.lib // builtins;

      inputs = proxy;

      perSystem = { self', pkgs, system, inputs', config, ... }:
        let
          intermediary = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          bootstrap = crane.lib.${system}.overrideToolchain intermediary;

          bootstrapArgs = {
            pname = "uninix";
            version = self.rev or "dirty";
            src = bootstrap.cleanCargoSource ./.;
          };

          artifacts = bootstrap.buildDepsOnly bootstrapArgs;
          uninix-bootstrap = bootstrap.buildPackage (bootstrapArgs // { inherit artifacts; });
        in
        {
          apps = {
            uninix-bootstrap = {
              type = "app";
              program = base.getExe self'.packages.uninix-bootstrap;
            };

            format = {
              type = "app";
              program =
                let path = base.makeBinPath [ pkgs.nixpkgs-fmt ];
                in base.toString (pkgs.writeScript "format" ''
                  export PATH="${path}"
                  ${pkgs.treefmt}/bin/treefmt --clear-cache "$@"
                '');
            };
          };

          checks = {
            uninix-bootstrap = uninix-bootstrap;

            pre-commit-check = commit.lib.${system}.run {
              src = ./.;
              hooks = {
                treefmt = {
                  enable = true;
                  name = "treefmt";
                  pass_filenames = false;
                  entry = base.toString (pkgs.writeScript "treefmt" ''
                    #!${pkgs.bash}/bin/bash
                    export PATH="$PATH:${base.makeBinPath [pkgs.nixpkgs-fmt]}"
                    ${pkgs.treefmt}/bin/treefmt --clear-cache --fail-on-change
                  '');
                };
              };
            };
          };

          packages = {
            uninix-bootstrap = uninix-bootstrap;
          };

          # tysm NyCodeGHG for helping with this
          # check out her code !
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              rust.overlays.default
            ];
          };
        };
    in
    parts.lib.mkFlake { inherit inputs; } {
      imports = [ ./modules/flake-parts/all-modules.nix ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      inherit perSystem;
    };
}

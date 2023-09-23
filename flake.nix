{
  description = "universal nix: plug-n-play nix with build tooling";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    parts.url = "github:hercules-ci/flake-parts";
    parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    commit.url = "github:cachix/pre-commit-hooks.nix";
    commit.inputs.nixpkgs.follows = "nixpkgs";

    crane.url = "github:ipetkov/crane";
    crane.inputs.nixpkgs.follows = "nixpkgs";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, parts, commit, ... } @ proxy:
    let
      inputs = proxy;

      base = nixpkgs.lib // builtins;
      makeLibrary = pkgs: import ./modules/library {
        inherit (pkgs) lib newScope;
      };
      perSystem = { self', pkgs, system, inputs', ... }: {
        intermediary = import ./packages {
          inherit pkgs;
          library = makeLibrary pkgs;
        };

        apps = {
          format.type = "app";
          format.program =
            let
              path = base.makeBinPath [ pkgs.nixpkgs-fmt ];
            in
            base.toString (pkgs.writeScript "format" ''
              export PATH="${path}"
              ${pkgs.treefmt}/bin/treefmt --clear-cache "$@"
            '');
        };

        devShells =
          let
            _devshell = import "${proxy.devshell}/modules" pkgs;
            makeDevshell = config: (_devshell {
              configuration = {
                inherit config;
                imports = [ ];
              };
            }).shell;
          in
          rec {
            default = uninix-module;
            uninix-module = makeDevshell {
              devshell.name = "uninix-module";
              devshell.startup = {
                preCommitHooks.text = self.checks.${system}.pre-commit-check.shellHook;
                uninixEnv.text = ''export NIX_PATH=nixpkgs=${nixpkgs}'';
              };

              packages = [ pkgs.nixpkgs-fmt pkgs.mdbook ];
              commands = [
                {
                  package = pkgs.treefmt;
                  category = "formatting";
                }
              ] ++ base.optional pkgs.stdenv.isLinux {
                package = pkgs.cntr;
                category = "debugging";
              };
            };
          };

        checks = {
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

        packages = { };

        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [ ];
        };
      };
    in
    parts.lib.mkFlake { inherit inputs; } {
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

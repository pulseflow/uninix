(import ./default.nix).devShells.${builtins.currentSystem}.default
  or (throw "dev-shell not defined. cannot find flake attributes devShell.${builtins.currentSystem}.default")

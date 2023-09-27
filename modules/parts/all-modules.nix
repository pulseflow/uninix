{ config, lib, ... }:

let
  inherit (builtins) attrValues mapAttrs readDir;
  inherit (lib) mapAttrs' filterAttrs nameValuePair removeSuffix mkOption types;

  modulesDir = ../.;
  moduleKinds = filterAttrs (_: type: type == "directory") (readDir modulesDir);
  mapModules = kind: mapAttrs'
    (fn: _: nameValuePair
      (removeSuffix ".nix" fn)
      (modulesDir + "/${kind}/${fn}")
    )
    (readDir (modulesDir + "/${kind}"));
  flakePartsModules = attrValues
    (filterAttrs
      (modName: _: modName != "all-modules")
    )
    (mapModules "parts");
in
{
  imports = flakePartsModules;
  options.flake.modules = mkOption {
    type = types.lazyAttrsOf types.raw;
  };

  config.flake.modules = mapAttrs (kind: _: mapModules kind) moduleKinds;
  config.flake.nixosModules = config.flake.modules.nixos or { };
  config.flake.darwinModules = config.flake.modules.darwin or { };
}

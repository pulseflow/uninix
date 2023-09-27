{ self, lib, inputs, ... }:

{
  flake.options.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
  };

  flake.config.lib.importPackages =
    args @ {
      projectRoot,
      projectRootFile,
      packagesDir,
      ...
    }:
    let
      projectRoot = toString args.projectRoot;
      packagesDir = toString args.packagesDir;
      packagesDirPath =
        if lib.hasPrefix projectRoot packagesDir
        then packagesDir else projectRoot + "/${packagesDir}";
      forwardedArgs = builtins.removeAttrs args [
        "projectRoot"
        "projectRootFile"
        "packagesDir"
      ];
    in
    lib.mapAttrs
      (module: type: self.lib.evalModules (forwardedArgs // {
        modules = args.modules or [ ] ++ [
          (packagesDirPath + "/${module}")
          {
            paths.projectRoot = projectRoot;
            paths.projectRootFile = projectRootFile;
            paths.package = packagesDir + "/${module}";
          }
        ];
      }))
      (builtins.readDir packagesDirPath);

  flake.config.lib.evalModules =
    args @ {
      packageSets,
      modules,
      raw ? false,
      specialArgs ? { },
      ...
    }:
    let
      forwardedArgs = builtins.removeAttrs args [ "packageSets" "raw" ];
      evaluated = lib.evalModules (forwardedArgs // {
        modules = args.modules ++ [ self.modules.uninix.core ];
        specialArgs = specialArgs // {
          inherit packageSets;
          uninix.modules.uninix = self.modules.uninix;
          uninix.overrides = self.overrides;
          uninix.lib.evalModules = self.lib.evalModules;
        };
      });
      result = if raw then evaluated else evaluated.config.public;
    in
    result;
}

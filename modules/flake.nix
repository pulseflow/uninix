{
  description = "(modules) universal nix: plug-n-play nix with build tooling";

  outputs = _:
    let
      modulesDir = ./.;

      inherit
        (builtins)
        attrNames
        concatMap
        listToAttrs
        mapAttrs
        readDir
        stringLength
        substring;

      nameValuePair = name: value: { inherit name value; };
      filterAttrs = pred: set: listToAttrs
        (concatMap (name: let v = set.${name}; in if pred name v then [ (nameValuePair name v) ] else [ ])
          (attrNames set));
      moduleKinds = filterAttrs (_: type: type == "directory") (readDir modulesDir);
      mapAttrs' = f: set: listToAttrs (map (attr: f attr set.${attr}) (attrNames set));
      removeSuffix = suffix: str: (
        let sufLen = stringLength suffix; strLen = stringLength str;
        in if sufLen <= strLen && suffix == substring (strLen - sufLen) sufLen str then substring 0 (strLen - sufLen) str else str
      );
      mapModules = kind: mapAttrs'
        (fn: _: {
          name = removeSuffix ".nix" fn;
          value = modulesDir + "/${kind}/${fn}";
        })
        (readDir (modulesDir + "/${kind}"));
    in
    {
      modules = mapAttrs (kind: _: mapModules kind) moduleKinds;
    };
}

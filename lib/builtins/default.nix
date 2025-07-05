{ pkgs
, lib,
...
}:
let
  remarshal = inputFormat: outputFormat: text:
    pkgs.runCommand
      "remarshalFromNix"
      { nativeBuildInputs = [ pkgs.remarshal ]; }
      "command cat ${text} | remarshal -if ${inputFormat} -of ${outputFormat}";
in {
  isExistAndEnable = attr: attrset:
    (builtins.hasAttr attr attrset)
    && (builtins.hasAttr "enable" attrset.${attr})
    && (attrset.${attr}.enable);

  set = value: list:
    let
      kV = builtins.map (item: (lib.nameValuePair item value)) list;
    in
    builtins.listToAttrs kV;

  toYaml = obj:
    (pkgs.formats.yaml { }).generate "toYaml" obj;
  toToml = obj:
    (pkgs.formats.toml { }).generate "toToml" obj;

  # TODO: not working.
  fromYaml = text:
    builtins.fromJSON (remarshal "yaml" "json" text);

  toSessionVariables = map:
    let
      # builtins.toString converts boolean "true" "false" to "1" "".
      # https://nixos.org/manual/nix/stable/language/builtins.html#builtins-toString
      vars = (lib.attrsets.mapAttrsToList (name: value:
        if builtins.typeOf value == "bool" then
          "${name}=${lib.trivial.boolToString value}"
        else
          "${name}=${builtins.toString value}"
        ) map);
    in builtins.concatStringsSep "\n" vars;

  # From ai
  fromDotenv = path:
    let
      content = builtins.readFile path;
      parseDotenv = content: let
        lines = lib.splitString "\n" content;
        validLines = builtins.filter (line: line != "" && (builtins.isNull (builtins.match "^#" line))) lines;
        nonEmptyAttrs = x: x != {} && (builtins.length (builtins.attrNames x) > 0);
        kvPairs = builtins.map (line:
          let
            parts = lib.splitString "=" line;
          in
            if builtins.length parts == 2 then
              lib.nameValuePair
                (lib.trim (builtins.head parts))
                (lib.trim (lib.last parts))
            else
              {}
        ) validLines;
      in
        builtins.listToAttrs (builtins.filter nonEmptyAttrs kvPairs);
    in parseDotenv content;

  # ======================================================================
  # flatten — Flattens a nested AttrSet into a set of dot-separated keys.
  #
  # attention: set derivation as path, not as pkgs directly. If use pkgs, infinite recursion will occur.
  #
  # Parameters:
  #   ignoreAttrKey : String
  #     If an AttrSet contains this key, its entire set (minus the ignoreAttrKey) is returned as a single entry and not recursed into.
  #   set : AttrSet
  #     The nested AttrSet to flatten.
  #
  # Usage example:
  #   let
  #     testSet = {
  #       foo = {
  #         bar      = 1;
  #         stopHere = "ignored";
  #       };
  #       baz = {
  #         qux = {
  #           quux = 2;
  #         };
  #       };
  #     };
  #   in flatten "stopHere" testSet
  #
  # Expected result:
  # {
  #   "foo" = { bar = 1; };
  #   "baz.qux.quux"   = 2;
  # }
  # https://discourse.nixos.org/t/flatten-nested-set-to-name-value-pairs-named-after-the-old-path/59713
  flatten =
    ignoreAttrKey:
    set:
    let
      recurse =
        path:
        lib.concatMapAttrs (
          name: value:
          if builtins.isAttrs value then
            if (builtins.hasAttr ignoreAttrKey value) then
              { ${builtins.concatStringsSep "." (path ++ [ name ])}
                = (builtins.removeAttrs value [ ignoreAttrKey ]); }
            else
              recurse (path ++ [ name ]) value
          else
            { ${builtins.concatStringsSep "." (path ++ [ name ])} = value; }
        );
    in
    recurse [ ] set;
}

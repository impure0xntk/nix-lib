{ pkgs, lib }:

let
  builtinsLib = import ../lib/builtins/default.nix { inherit pkgs lib; };

  # for isExistAndEnable
  testAttrSetEnable = { enable = true; foo = "bar"; };
  testAttrSetDisable = { enable = false; foo = "bar"; };
  testAttrSetNoEnable = { foo = "bar"; };
  testAttrSetEmpty = {};

  # for toYaml
  testYamlObj = {
    a = 1;
    b = "hello";
    c = { d = true; };
  };
  testYaml = builtinsLib.toYaml testYamlObj;
  expectedYaml = pkgs.writeText "expected.yaml" ''
    a: 1
    b: hello
    c:
      d: true
  '';

  # for toToml
  testTomlObj = {
    a = 1;
    b = "hello";
    c = { d = true; };
  };
  testToml = builtinsLib.toToml testTomlObj;
  expectedToml = pkgs.writeText "expected.toml" ''
    a = 1
    b = "hello"

    [c]
    d = true
  '';

  # for toSessionVariables
  testSessionVarsObj = {
    VAR1 = "value1";
    VAR2 = 123;
    VAR3 = true;
    VAR4 = false;
  };
  testSessionVars = builtinsLib.toSessionVariables testSessionVarsObj;
  expectedSessionVarsFile = pkgs.writeText "expected.vars" ''
    VAR1=value1
    VAR2=123
    VAR3=true
    VAR4=false
  '';

  # for fromDotenv
  dotenvContent = ''
    # This is a comment
    KEY1=VALUE1
    KEY2="Quoted Value"
    KEY3 = spaced_value
    # Another comment
    INVALID_LINE
    KEY4=
  '';
  dotenvFile = pkgs.writeText "test.env" dotenvContent;
  testFromDotenv = builtinsLib.fromDotenv dotenvFile;

  # for flatten
  testFlattenSet = {
    foo = {
      bar = 1;
      stopHere = "ignored"; # This should not be recursed into
    };
    baz = {
      qux = {
        quux = 2;
      };
    };
    a = "toplevel";
  };
  flattenedSet = builtinsLib.flatten "stopHere" testFlattenSet;

in
  # Test isExistAndEnable
  assert (builtinsLib.isExistAndEnable "test" { test = testAttrSetEnable; }) == true;
  assert (builtinsLib.isExistAndEnable "test" { test = testAttrSetDisable; }) == false;
  assert (builtinsLib.isExistAndEnable "test" { test = testAttrSetNoEnable; }) == false;
  assert (builtinsLib.isExistAndEnable "test" { test = testAttrSetEmpty; }) == false;
  assert (builtinsLib.isExistAndEnable "nonexistent" { test = testAttrSetEnable; }) == false;

  # Test set
  assert ((builtinsLib.set "value" [ "key1" "key2" ]).key1) == "value";
  assert ((builtinsLib.set "value" [ "key1" "key2" ]).key2) == "value";

  # Test toYaml
  assert (builtins.readFile testYaml) == (builtins.readFile expectedYaml);

  # Test toToml
  assert (builtins.readFile testToml) == (builtins.readFile expectedToml);

  # Test toSessionVariables
  assert (
    let
      actualLines = (lib.splitString "\n" (lib.removeSuffix "\n" testSessionVars));
      expectedLines = (lib.splitString "\n" (lib.removeSuffix "\n" (builtins.readFile expectedSessionVarsFile)));
    in actualLines == expectedLines
  );

  # Test fromDotenv
  assert testFromDotenv.KEY1 == "VALUE1";
  assert testFromDotenv.KEY2 == "\"Quoted Value\"";
  assert testFromDotenv.KEY3 == "spaced_value";
  assert (builtins.hasAttr "KEY4" testFromDotenv) && testFromDotenv.KEY4 == "";
  assert !(builtins.hasAttr "INVALID_LINE" testFromDotenv);
  assert !(builtins.hasAttr "" testFromDotenv);

  # Test flatten
  assert flattenedSet.a == "toplevel";
  assert flattenedSet."baz.qux.quux" == 2;
  assert (builtins.isAttrs flattenedSet.foo);
  assert flattenedSet.foo.bar == 1;
  assert !(builtins.hasAttr "stopHere" flattenedSet.foo);
  assert !(builtins.hasAttr "baz.qux" flattenedSet);

  pkgs.runCommand "builtins-tests" { } ''
    touch $out
  ''
{ pkgs, lib }:

let
  builders = import ../lib/builders/default.nix { inherit pkgs lib; };

  # Test case 1: Basic functionality
  basicApp = builders.writeOilApplication {
    name = "basic-app";
    text = ''
      echo "Hello, Oil!"
    '';
  };
  basicAppContent = builtins.readFile "${basicApp}/bin/basic-app";

  # Test case 2: With errexit = true
  errexitApp = builders.writeOilApplication {
    name = "errexit-app";
    text = "true";
    errexit = true;
  };
  errexitAppContent = builtins.readFile "${errexitApp}/bin/errexit-app";

  # Test case 3: With custom includeOptions
  includeApp = builders.writeOilApplication {
    name = "include-app";
    text = "true";
    includeOptions = [ "opt1" "opt2" ];
  };
  includeAppContent = builtins.readFile "${includeApp}/bin/include-app";

  # Test case 4: With custom excludeOptions
  excludeApp = builders.writeOilApplication {
    name = "exclude-app";
    text = "true";
    excludeOptions = [ "opt3" ];
  };
  excludeAppContent = builtins.readFile "${excludeApp}/bin/exclude-app";

  # Test case 5: With both include and exclude options and errexit
  complexApp = builders.writeOilApplication {
    name = "complex-app";
    text = "true";
    errexit = true;
    includeOptions = [ "foo" ];
    excludeOptions = [ "bar" ];
  };
  complexAppContent = builtins.readFile "${complexApp}/bin/complex-app";

in
  # Assertions
  assert (lib.head (lib.splitString "\n" basicAppContent)) == "#!${pkgs.oil}/bin/osh";
  assert lib.strings.hasInfix ''echo "Hello, Oil!"'' basicAppContent;

  # Test case 1: Basic functionality
  assert lib.strings.hasInfix "shopt -s strict:all" basicAppContent;
  assert lib.strings.hasInfix "shopt -u strict_errexit" basicAppContent;

  # Test case 2: With errexit = true
  assert lib.strings.hasInfix "shopt -s strict:all" errexitAppContent;
  assert lib.strings.hasInfix "strict_errexit" errexitAppContent;

  # Test case 3: With custom includeOptions
  assert lib.strings.hasInfix "shopt -s strict:all opt1 opt2" includeAppContent;
  assert lib.strings.hasInfix "shopt -u strict_errexit" includeAppContent;

  # Test case 4: With custom excludeOptions
  assert lib.strings.hasInfix "shopt -u opt3" excludeAppContent;

  # Test case 5: With both include and exclude options and errexit
  assert lib.strings.hasInfix "shopt -u bar" complexAppContent;
  assert lib.strings.hasInfix "shopt -s strict:all foo" complexAppContent;
  assert lib.strings.hasInfix "strict_errexit" complexAppContent;

  # Final derivation for nix flake check
  pkgs.runCommand "builders-tests" { } ''
    touch $out
  ''
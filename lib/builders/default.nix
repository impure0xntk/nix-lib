{ pkgs
, lib,
...
}:
let
  interpreterParameters = {
    oil = {
      executableName = "osh";
      defaultIncludeOption = ["strict:all"];
      defaultExcludeOption = [];
    };
    ysh = {
      executableName = "ysh";
      defaultIncludeOption = ["ysh:all"];
      defaultExcludeOption = [];
    };
  };
in rec {
  writeOvmApplication = { name
    , text
    , runtimeInputs ? [ ]
    , meta ? { }
    , checkPhase ? null
    , excludeShellChecks ? []

    , errexit ? false

    , executableName
    , includeOptions ? []
    , excludeOptions ? []
    }:
    let
      # writeShellApplication is function, not derivation.
      # So pkgs.writeShellApplication.override~ is not working.
      # shellApplication = pkgs.writeShellApplication {
      shellApplication = pkgs.writeShellApplication {
        inherit name text runtimeInputs meta checkPhase excludeShellChecks;
      };
      substitutes =
        let
          hasIncludeOptions = builtins.length includeOptions > 0;
          hasExcludeOptions = builtins.length excludeOptions > 0;
          substituteIncludeOptions = if hasIncludeOptions then "shopt -s " + builtins.concatStringsSep " " (
            includeOptions
            ++ (if errexit then ["strict_errexit"] else ["; shopt -u strict_errexit"])) + ";"
            else "";
          substituteExcludeOptions = if hasExcludeOptions then "shopt -u " + builtins.concatStringsSep " "
            excludeOptions
            + ";"
            else "";
        in
        (if ! hasIncludeOptions && ! hasExcludeOptions then
          ""
        else
          "${substituteIncludeOptions} ${substituteExcludeOptions}"
        );
    in (shellApplication).overrideAttrs(old: rec {
      runtimeInputs = [pkgs.oils-for-unix];
      # To patch all shebangs as oil/ysh, disable dontPatchShebangs.
      # Last line executes to check format.
      # Expected workflow:
      # 1. Develop shellscript files (with local shebangs).
      # 2. Read 1 file and input as arg "text".
      # 3. Patch as runtimeShell on pkgs.writeShellApplication.
      checkPhase = old.checkPhase + ''
        substituteInPlace $out/bin/${name} \
          --replace '${pkgs.runtimeShell}' '${pkgs.oils-for-unix}/bin/${executableName}' \
          --replace 'set -o nounset' "" \
          --replace 'set -o pipefail' "" \
          --replace 'set -o errexit' '${substitutes}'

        '${pkgs.oils-for-unix}/bin/${executableName}' --ast-format none -n "$target"
      '';
    });

  writeOilApplication = { name
    , text
    , runtimeInputs ? [ ]
    , meta ? { }
    , checkPhase ? null
    , excludeShellChecks ? []

    , errexit ? false
    , includeOptions ? []
    , excludeOptions ? []
    }: writeOvmApplication {
      inherit name text runtimeInputs meta checkPhase excludeShellChecks errexit;
      executableName = interpreterParameters.oil.executableName;
      includeOptions = interpreterParameters.oil.defaultIncludeOption ++ includeOptions;
      excludeOptions = interpreterParameters.oil.defaultExcludeOption ++ excludeOptions;
    };

  # writeYshApplication = { name
  #   , text
  #   , runtimeInputs ? [ ]
  #   , meta ? { }

  #   , errexit ? false
  #   , includeOptions ? []
  #   , excludeOptions ? []
  #   }: writeOvmApplication {
  #     inherit name text runtimeInputs meta errexit;
  #     checkPhase = ""; # shellcheck cannot parse ysh.

  #     executableName = interpreterParameters.ysh.executableName;
  #     includeOptions = interpreterParameters.ysh.defaultIncludeOption ++ includeOptions;
  #     excludeOptions = interpreterParameters.ysh.defaultExcludeOption ++ excludeOptions;
  #   };
}

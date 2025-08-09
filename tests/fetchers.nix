{ pkgs, lib }:

let
  fetchers = import ../lib/fetchers/default.nix { inherit pkgs lib; };

  # fetchurl requires a hash, so provide dummy arguments.
  dummyArgs = {
    url = "https://ash-speed.hetzner.com/100MB.bin";
    # Dummy sha256 hash value (must be valid format).
    hash = "sha256-KcG1gwTIqQZLdH4/MTMEp1uI++v+2vsydQBjZ/4gLfg=";
  };

  fetchurlBinaryDrv = fetchers.fetchurlBinary dummyArgs;
  fetchurlBinaryDrvAttrs = fetchurlBinaryDrv.drvAttrs;

  fetchurlBinaryLegacyDrv = fetchers.fetchurlBinaryLegacy dummyArgs;
  fetchurlBinaryLegacyDrvAttrs = fetchurlBinaryLegacyDrv.drvAttrs;

in
  # fetchurlBinary must add aria2 to nativeBuildInputs.
  assert lib.lists.any (p: lib.strings.hasInfix "aria2" (lib.getName p)) fetchurlBinaryDrvAttrs.nativeBuildInputs;

  # fetchurlBinary must override the builder.
  assert lib.lists.any (arg: lib.strings.hasSuffix "fetchurlBinary-builder.sh" (toString arg)) fetchurlBinaryDrvAttrs.args;

  # fetchurlBinaryLegacy must have specific curlOptsList.
  assert lib.strings.hasInfix "-fsSL" fetchurlBinaryLegacyDrvAttrs.curlOptsList && lib.strings.hasInfix "Accept: application/octet-stream" fetchurlBinaryLegacyDrvAttrs.curlOptsList;

  pkgs.runCommand "fetchers-tests" { } ''
    echo "downloaded ${fetchurlBinaryDrv} ${fetchurlBinaryLegacyDrv}"
    echo "fetchers tests passed"
    touch $out
  ''

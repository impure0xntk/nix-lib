{ pkgs
, lib,
...
}:
let
in rec {
  fetchurlBinary = args@{url, hash, ...}:
    (pkgs.fetchurl args).overrideAttrs (old: rec {
      nativeBuildInputs = old.nativeBuildInputs ++ (with pkgs; [
        aria2
      ]);
      builder = ./fetchurlBinary-builder.sh;
    });
  fetchurlBinaryLegacy = {url, hash, ...}:
    pkgs.fetchurl {
      inherit url hash;
      curlOptsList = ["-fsSL" "-H" "Accept: application/octet-stream"];
    };
}

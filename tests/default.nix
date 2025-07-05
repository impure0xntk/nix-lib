
{ pkgs, lib, }:

pkgs.runCommand "overlay-test" { } ''
  set -x
  echo "${lib.strings.concatStringsSep " " (lib.my.listDirs {path = ./..;})}" > $out
  SIZE=$(stat -c %s $out)
  test "$SIZE" -gt 0
  set +x
''

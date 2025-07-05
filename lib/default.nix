attrs@{lib, ...}:
with builtins;
with lib;

let
  # Load child directories(not recursive)
  # Tip: use lib.filesystem.listFilesRecursive if you want to list all files in a directory recursively.
  forEachDirs = f: path: let
    topEntries = readDir path;
    topDirectoryEntries = filterAttrs f topEntries;
    topDirectories = mapAttrsToList (n: v: path + ("/" + n)) topDirectoryEntries;
  in
    topDirectories;

  listDirs = {path, excludeDirPaths ? []}: let
    f = n: v: v == "directory";
  in
    lib.subtractLists excludeDirPaths (forEachDirs f path);

  listDefaultNixDirs = {path, excludeDirPaths ? []}:
    filter (n: pathExists (n + "/default.nix")) (listDirs {inherit path excludeDirPaths;});

  importDirs = args@{path, excludeDirPaths ? [], ...}: let
    arguments = builtins.removeAttrs args [ "path" "excludeDirPaths" ];
  in
   (lib.foldl' (acc: curr: acc // curr) {} (
    lib.forEach (listDefaultNixDirs {inherit path excludeDirPaths;}) (v: import v arguments)));

  listImportLocs = {path, excludeDirPaths ? []}: let
    f = n: v: v == "directory" || (lib.hasSuffix ".nix" n && v == "regular");
  in
    lib.subtractLists excludeDirPaths (forEachDirs f path);

in (
  (importDirs ({path = ./.;} // attrs))
  // {
    inherit listDirs listDefaultNixDirs importDirs listImportLocs;
  }
)

{pkgs, lib, ...}:
{
  genOverlayPackages = path: finalPkgs: args:
    let
      packageList = lib.my.listDirs { inherit path; };
      packages = builtins.listToAttrs (
        map ( v: { name = baseNameOf v; value = (finalPkgs.callPackage v args); } )
        packageList);
    in packages;
}

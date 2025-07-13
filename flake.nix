{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      createLibOverlay =
        pkgs:
        (final: prev: {
          my = import ./lib {
            inherit pkgs;
            lib = prev;
          };
        });
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib.extend (createLibOverlay pkgs);
      in
      {
        inherit lib;
        checks.lib-extend = import ./tests { inherit pkgs lib; };
      }
    );
}

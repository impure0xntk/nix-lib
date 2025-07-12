{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      overlay = final: prev: {
        lib = prev.lib.extend (selflib: superlib: {
          my = import ./lib {
            pkgs = final;
            lib = superlib;
          };
        });
      };
    in
    {
      overlays.default = overlay;
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
        lib = pkgs.lib;
      in
      {
        lib = lib.my;
        checks.lib-extend = import ./tests { inherit pkgs lib; };
      });
}
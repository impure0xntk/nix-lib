{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      overlay = final: prev: {
        my = import ./lib {
          pkgs = final;
          lib = prev;
        };
      };
    in
    {
      overlays.default = overlay;
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib.extend (self.overlays.default);
      in
      {
        inherit lib;
        checks.lib-extend = import ./tests { inherit pkgs lib; };
      });
}
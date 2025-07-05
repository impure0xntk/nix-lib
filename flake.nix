{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      overlays.default = final: prev: {
        my = import ./lib {
          inherit pkgs;
          lib = prev;
        };
      };

      checks.${system}.lib-extend =
        let
          lib = pkgs.lib.extend (self.overlays.default);
        in
        import ./tests { inherit pkgs lib; };
    };
}
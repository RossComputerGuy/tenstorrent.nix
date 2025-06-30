{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    systems.url = "github:nix-systems/default-linux";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = {
    self,
    nixpkgs,
    systems,
    flake-parts,
    ...
  }@inputs: flake-parts.lib.mkFlake { inherit inputs; } ({ lib, inputs, ... }: {
    systems = import inputs.systems;
    flake.overlays.default = import ./pkgs/overlay.nix;
    perSystem = { pkgs, ... }:
    let
      pkgsTenstorrent = pkgs.callPackages ./pkgs/default.nix { };
    in {
      packages = pkgsTenstorrent;
    };
  });
}

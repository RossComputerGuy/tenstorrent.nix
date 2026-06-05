{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    systems.url = "github:nix-systems/default-linux";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    { self, ... }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [
        inputs.treefmt-nix.flakeModule
      ];

      flake = {
        overlays.default = import ./overlay.nix;
        nixosModules.default = ./nixos/module.nix;
      };

      perSystem =
        { system, pkgs, ... }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              self.overlays.default
            ];
          };

          treefmt.programs = {
            nixfmt.enable = true;
          };

          packages = {
            inherit (pkgs)
              enchantum
              llama-cpp-metalium
              luwen
              nanobench
              tt-burnin
              tt-logger
              tt-metal
              tt-smi
              tt-system-tools
              tt-topology
              tt-umd
              ;
            inherit (pkgs.python3Packages)
              pyluwen
              tt-flash
              tt-tools-common
              ;
            inherit (pkgs.linuxPackagesFor pkgs.linux) tt-kmd;
          };

          checks = {
            inherit (pkgs)
              enchantum
              llama-cpp-metalium
              luwen
              nanobench
              tt-burnin
              tt-logger
              tt-metal
              tt-smi
              tt-system-tools
              tt-topology
              tt-umd
              ;
            inherit (pkgs.python3Packages)
              pyluwen
              tt-flash
              tt-tools-common
              ;
            inherit (pkgs.linuxPackagesFor pkgs.linux) tt-kmd;
          };
        };
    };
}

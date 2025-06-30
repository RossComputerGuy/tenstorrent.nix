{
  inputs,
  lib,
  newScope,
  buildPackages,
  callPackage,
}@pkgs:
lib.makeScope newScope (self: with self;
let
  isl_0_23 = (pkgs.callPackage (import "${inputs.nixpkgs}/pkgs/development/libraries/isl/generic.nix" rec {
    version = "0.23";
    urls = [
      "mirror://sourceforge/libisl/isl-${version}.tar.xz"
      "https://libisl.sourceforge.io/isl-${version}.tar.xz"
    ];
    sha256 = "sha256-XvxT767xUTAfTn3eOFa2aBLYFT3t4k+rF2c/gByGmPI=";
    configureFlags = [
      "--with-gcc-arch=generic" # don't guess -march=/mtune=
    ];
  }) { }).overrideAttrs {
    depsBuildBuild = [ buildPackages.stdenv.cc ];
  };
in {
  metal = callPackage ./metal { inherit isl_0_23; };
  logger = callPackage ./logger { };
})

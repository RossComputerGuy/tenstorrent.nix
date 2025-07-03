{
  inputs,
  lib,
  newScope,
  buildPackages,
  callPackage,
  python3Packages,
  linux,
}@pkgs:
lib.makeScope newScope (
  self:
  with self;
  let
    isl_0_23 =
      (pkgs.callPackage (import "${inputs.nixpkgs}/pkgs/development/libraries/isl/generic.nix" rec {
        version = "0.23";
        urls = [
          "mirror://sourceforge/libisl/isl-${version}.tar.xz"
          "https://libisl.sourceforge.io/isl-${version}.tar.xz"
        ];
        sha256 = "sha256-XvxT767xUTAfTn3eOFa2aBLYFT3t4k+rF2c/gByGmPI=";
        configureFlags = [
          "--with-gcc-arch=generic" # don't guess -march=/mtune=
        ];
      }) { }).overrideAttrs
        {
          depsBuildBuild = [ buildPackages.stdenv.cc ];
        };
  in
  {
    metal = self.callPackage ./metal { inherit isl_0_23; };
    kmd = self.callPackage ./kmd { kernel = linux; };
    tools-common = self.callPackage ./tools-common {
      inherit (python3Packages)
        buildPythonApplication
        setuptools
        distro
        elasticsearch
        psutil
        pyyaml
        rich
        textual
        requests
        tqdm
        pydantic
        ;
    };
    pyluwen = self.callPackage ./pyluwen {
      inherit (python3Packages) buildPythonApplication;
    };
    flash = self.callPackage ./flash {
      inherit (python3Packages)
        buildPythonApplication
        setuptools
        tabulate
        pyyaml
        ;
    };
    smi = self.callPackage ./smi {
      inherit (python3Packages)
        buildPythonApplication
        setuptools
        distro
        elasticsearch
        pydantic
        rich
        textual
        importlib-resources
        ;
    };
  }
)

{
  lib,
  stdenv,
  fetchurl,
  runCommand,
  autoPatchelfHook,
  ncurses,
  isl_0_23,
  mpfr,
  libmpc,
  xz,
  zstd,
  expat,
}:
let
  version = "7.49.0";
in
runCommand "sfpi-${version}"
  {
    inherit version;

    nativeBuildInputs = [
      autoPatchelfHook
    ];

    buildInputs = [
      ncurses
      isl_0_23
      mpfr
      libmpc
      xz
      zstd
      expat
    ];

    src =
      {
        aarch64-linux = fetchurl {
          url = "https://github.com/tenstorrent/sfpi/releases/download/${version}/sfpi_${version}_aarch64_debian.txz";
          hash = "sha256-HcoCLB4Jl2QyX5gznnfO/4wtzsWcyhwCXNqUBJljJX4=";
        };
        x86_64-linux = fetchurl {
          url = "https://github.com/tenstorrent/sfpi/releases/download/${version}/sfpi_${version}_x86_64_debian.txz";
          hash = "sha256-CxlaPhFQfe1FY+wDwwUAgUbFX7I/1q5zvqb/4WmJOb0=";
        };
      }
      ."${stdenv.hostPlatform.system}" or (throw "SFPI does not support ${stdenv.hostPlatform.system}");
  }
  ''
    runPhase unpackPhase
    cp -r ../"$sourceRoot" "$out"
    runPhase fixupPhase
  ''

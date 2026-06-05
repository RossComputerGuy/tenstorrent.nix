{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  fetchzip,
  applyPatches,
  callPackage,
  pkg-config,
  cmake,
  ninja,
  boost,
  capstone,
  numactl,
  mpi,
  hwloc,
  python3,
  fmt,
  nlohmann_json,
  gbenchmark,
  capnproto,
  gtest,
  spdlog,
  yaml-cpp,
  tt-logger,
  enchantum,
  simde,
  xtl,
  xtensor,
  xtensor-blas,
  range-v3,
  libblake3,
  blas,
  lapack,
}:
stdenv.mkDerivation (
  finalAttrs:
  let
    deps = import ./deps.nix {
      inherit
        fetchFromGitHub
        fetchzip
        applyPatches
        ;
      tt-metal-src = finalAttrs.src;
    };
  in
  {
    pname = "tt-metal";
    version = "0.71.2";

    src = fetchFromGitHub {
      owner = "tenstorrent";
      repo = "tt-metal";
      tag = "v${finalAttrs.version}";
      fetchSubmodules = true;
      hash = "sha256-7gLL94vINP+AwUVgF6681MFtXhaQ08rKxyWlJ5IYubU=";
    };

    cpm = fetchurl {
      url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.2/CPM.cmake";
      hash = "sha256-yM3DLAOBZTjOInge1ylk3IZLKjSjENO3EEgSpcotg10=";
    };

    sfpi = callPackage ./sfpi.nix { };

    patches = [
      # https://github.com/tenstorrent/tt-metal/pull/46222
      ./cadical-local.patch
      ./umd-asio-local.patch
      # https://github.com/tenstorrent/tt-metal/pull/46224
      ./local-find-package.patch
      # https://github.com/tenstorrent/tt-metal/pull/46226
      ./header-only-local.patch
      # https://github.com/tenstorrent/tt-metal/pull/46229
      ./patched-pins-local.patch
      # https://github.com/tenstorrent/tt-umd/pull/2187
      ./umd-targets-local.patch
    ];

    postUnpack = ''
      mkdir -p "$sourceRoot/runtime"
      ln -s "$sfpi" "$sourceRoot/runtime/sfpi"
    '';

    postPatch = ''
      cp $cpm cmake/CPM.cmake
      cp $cpm tt_metal/third_party/umd/cmake/CPM.cmake
      patchShebangs .
      substituteInPlace tt_metal/sfpi-info.sh --replace-fail "sfpi_dist=unknown" "sfpi_dist=debian"
      substituteInPlace third_party/CMakeLists.txt --replace-fail "NAME googletest" "NAME GTest"
    '';

    cmakeFlags = [
      (lib.cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
      (lib.cmakeBool "CPM_USE_LOCAL_PACKAGES" true)
      (lib.cmakeBool "WITH_PYTHON_BINDINGS" true)
      (lib.cmakeBool "TT_INSTALL" true)
      (lib.cmakeFeature "VERSION_NUMERIC" finalAttrs.version)
      (lib.cmakeFeature "CMAKE_POLICY_VERSION_MINIMUM" "3.10")
      (lib.cmakeFeature "cadical_SOURCE_DIR" (builtins.toString deps.cadical))
      (lib.cmakeFeature "umd_asio_SOURCE_DIR" (builtins.toString deps.umd_asio))
      (lib.cmakeFeature "CAPNP_INCLUDE_DIRECTORY" "${lib.getDev capnproto}/include")
      (lib.cmakeFeature "reflect_SOURCE_DIR" (builtins.toString deps.reflect))
      (lib.cmakeFeature "simd-everywhere_SOURCE_DIR" "${simde}/include")
    ];

    preConfigure = ''
      mkdir -p build/_deps
      ${lib.concatMapAttrsStringSep "\n" (
        name: src: "cp -r --no-preserve=ownership,mode ${src} build/_deps/${name}-src"
      ) deps}
    '';

    env.NIX_CFLAGS_COMPILE = "-Wno-error=unused-but-set-variable";

    enableParallelBuilding = true;

    nativeBuildInputs = [
      cmake
      ninja
      pkg-config
      python3
    ];

    buildInputs = [
      numactl
      boost
      capstone
      mpi
      hwloc
      fmt
      nlohmann_json
      gbenchmark
      capnproto
      gtest
      spdlog
      yaml-cpp
      tt-logger
      enchantum
      xtl
      xtensor
      xtensor-blas
      range-v3
      libblake3
      blas
      lapack
    ];

    postInstall = ''
      mkdir -p $out/${python3.sitePackages}
      cp -r ../ttnn/ttnn $out/${python3.sitePackages}/ttnn
      cp -r ../ttnn/tt_lib $out/${python3.sitePackages}/tt_lib
      cp -r ../tools/tracy $out/${python3.sitePackages}/tracy
      cp $out/lib/_ttnn.so $out/${python3.sitePackages}/ttnn/_ttnn.so

      mkdir -p $out/${python3.sitePackages}/ttnn-${finalAttrs.version}.dist-info
      cat > $out/${python3.sitePackages}/ttnn-${finalAttrs.version}.dist-info/METADATA <<EOF
      Metadata-Version: 2.1
      Name: ttnn
      Version: ${finalAttrs.version}
      EOF
    '';

    # Fixes the parallel hook crashing in the fixupPhase with no error.
    noAuditTmpdir = true;

    installTargets = [
      "install"
      "ttnn"
    ];

    meta = {
      description = "TT-NN operator library, and TT-Metalium low level kernel programming model";
      homepage = "https://github.com/tenstorrent/tt-metal";
      maintainers = with lib.maintainers; [ RossComputerGuy ];
      license = with lib.licenses; [ asl20 ];
      platforms = lib.platforms.linux;
    };
  }
)

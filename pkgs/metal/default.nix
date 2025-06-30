{
  lib,
  overrideCC,
  stdenv,
  llvmPackages_17,
  fetchFromGitHub,
  fetchurl,
  pkg-config,
  cmake,
  ninja,
  boost,
  numactl,
  yaml-cpp,
  gtest,
  magic-enum,
  fmt_11,
  range-v3,
  python3Packages,
  nlohmann_json,
  xtl,
  xtensor,
  taskflow,
  flatbuffers,
  spdlog,
  nanomsg,
  libuv,
  cxxopts,
  logger,
  mpi,
}:
(overrideCC stdenv llvmPackages_17.clangUseLLVM).mkDerivation (finalAttrs: {
  pname = "tt-metal";
  version = "0.59.0";

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = finalAttrs.pname;
    tag = "v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-D+PUqLfathq4tpRQueeVuWJE+1xkI3MCDIHnVaNBcVY=";
  };

  cpm = fetchurl {
    url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.2/CPM.cmake";
    hash = "sha256-yM3DLAOBZTjOInge1ylk3IZLKjSjENO3EEgSpcotg10=";
  };

  sfpiVersion = "6.12.0";
  sfpiSource = {
    aarch64-linux = fetchurl {
      url = "https://github.com/tenstorrent/sfpi/releases/download/v${finalAttrs.sfpiVersion}/sfpi-aarch64_Linux.txz";
      hash = "sha256-4RGwYhsEGx1/ANBUmNeSQcdmMRjFXN8Bg3DICLF6d5o=";
    };
  }."${stdenv.hostPlatform.system}";

  postUnpack = ''
    mkdir -p "$sourceRoot/deps"
    cp -r --no-preserve=ownership,mode ${fetchFromGitHub {
      owner = "xtensor-stack";
      repo = "xtensor-blas";
      tag = "0.22.0";
      hash = "sha256-Lg6MjJbZUCMqv4eSiZQrLfJy/86RWQ9P85UfeIQJ6bk=";
    }} $sourceRoot/deps/xtensor-blas

    mkdir -p "$sourceRoot/runtime"
    tar xf "$sfpiSource" -C "$sourceRoot/runtime"
  '';

  postPatch = ''
    cp $cpm cmake/CPM.cmake
    cp $cpm tt_metal/third_party/umd/cmake/CPM.cmake
  '';

  cmakeFlags = [
    (lib.cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
    (lib.cmakeBool "CPM_LOCAL_PACKAGES_ONLY" true)
    (lib.cmakeFeature "CPM_googletest_SOURCE" (toString gtest.src))
    (lib.cmakeFeature "CPM_reflect_SOURCE" (toString (fetchFromGitHub {
      owner = "boost-ext";
      repo = "reflect";
      tag = "v1.2.6";
      hash = "sha256-qjy5KyAm7/WeCyxMu/5QrBVjDSJPs0q/ZPyQwXp0WLA=";
    })))
    (lib.cmakeFeature "CPM_fmt_SOURCE" (toString fmt_11.src))
    (lib.cmakeFeature "CPM_xtensor-blas_SOURCE" "../../deps/xtensor-blas")
    (lib.cmakeFeature "CPM_benchmark_SOURCE" (toString (fetchFromGitHub {
      owner = "google";
      repo = "benchmark";
      tag = "v1.9.1";
      hash = "sha256-5xDg1duixLoWIuy59WT0r5ZBAvTR6RPP7YrhBYkMxc8=";
    })))
    (lib.cmakeFeature "CPM_Taskflow_SOURCE" (toString taskflow.src))
    (lib.cmakeFeature "CPM_simd-everywhere_SOURCE" (toString (fetchFromGitHub {
      owner = "simd-everywhere";
      repo = "simde";
      tag = "v0.8.2";
      hash = "sha256-igjDHCpKXy6EbA9Mf6peL4OTVRPYTV0Y2jbgYQuWMT4=";
    })))
    (lib.cmakeFeature "CPM_nanomsg_SOURCE" (toString nanomsg.src))
    (lib.cmakeFeature "CPM_libuv_SOURCE" (toString libuv.src))
  ];

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];

  buildInputs = [
    numactl
    boost
    yaml-cpp
    magic-enum
    range-v3
    python3Packages.pybind11
    nlohmann_json
    xtl
    xtensor
    flatbuffers
    spdlog
    cxxopts
    logger
    mpi
  ];

  meta = {
    description = "TT-NN operator library, and TT-Metalium low level kernel programming model.";
    homepage = "https://docs.tenstorrent.com/tt-metal/latest/ttnn";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ asl20 ];
  };
})

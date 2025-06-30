{
  lib,
  overrideCC,
  stdenv,
  llvmPackages_17,
  fetchurl,
  fetchFromGitHub,
  cmake,
  ninja,
  fmt_11,
  spdlog,
}:
(overrideCC stdenv llvmPackages_17.clangUseLLVM).mkDerivation (finalAttrs: {
  pname = "tt-logger";
  version = "1.1.4";

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = finalAttrs.pname;
    tag = "v${finalAttrs.version}";
    hash = "sha256-woOazBPnMGhqzPVux/zgwN+L8/KU94AnQ4u4KH4nye8=";
  };

  cpm = fetchurl {
    url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.2/CPM.cmake";
    hash = "sha256-yM3DLAOBZTjOInge1ylk3IZLKjSjENO3EEgSpcotg10=";
  };

  postPatch = ''
    cp $cpm cmake/CPM.cmake
  '';

  cmakeFlags = [
    (lib.cmakeBool "CPM_LOCAL_PACKAGES_ONLY" true)
    (lib.cmakeBool "TT_LOGGER_INSTALL" true)
    (lib.cmakeFeature "CPM_fmt_SOURCE" (toString fmt_11.src))
  ];

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    spdlog
  ];

  preInstall = ''
    mkdir -p $out
    cp -r ../include $out/include
  '';

  meta = {
    description = "Flexible and performant C++ logging library for Tenstorrent projects.";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ asl20 ];
  };
})

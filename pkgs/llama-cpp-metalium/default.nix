{
  lib,
  llama-cpp,
  fetchFromGitHub,
  tt-metal,
  tt-umd,
  tt-logger,
  yaml-cpp,
  fmt,
  nlohmann_json,
  spdlog,
  xtensor,
  python3,
  curl,
  enchantum,
}:
(llama-cpp.override { }).overrideAttrs (prevAttrs: {
  pname = "llama-cpp-metalium";
  version = "0-unstable-2026-06-05";

  src = fetchFromGitHub {
    owner = "marty1885";
    repo = "llama.cpp";
    rev = "89f4c5aa85833fc721041611dd23bf8025290901";
    hash = "sha256-gfjox90GDbUoiiWozQhWUEAW9YASty1qk78vMkQtanQ=";
  };

  patches = (prevAttrs.patches or [ ]) ++ [ ./metalium-find-package.patch ];

  npmRoot = null;
  npmDeps = null;
  preConfigure = "";

  nativeBuildInputs =
    builtins.filter (p: !(lib.hasInfix "npm" (p.name or ""))) (prevAttrs.nativeBuildInputs or [ ])
    ++ [ python3 ];

  buildInputs = (prevAttrs.buildInputs or [ ]) ++ [
    tt-metal
    tt-umd
    tt-logger
    yaml-cpp
    fmt
    nlohmann_json
    spdlog
    xtensor
    curl
    enchantum
  ];

  cmakeFlags = (prevAttrs.cmakeFlags or [ ]) ++ [
    (lib.cmakeBool "GGML_METALIUM" true)
    (lib.cmakeBool "GGML_CPU_ALL_VARIANTS" false)
    (lib.cmakeBool "GGML_SME" false)
    (lib.cmakeFeature "LLAMA_BUILD_NUMBER" "0")
  ];

  env = (prevAttrs.env or { }) // {
    TT_METAL_HOME = "${tt-metal}/libexec/tt-metalium";
  };

  meta = prevAttrs.meta // {
    description = "llama.cpp with Tenstorrent Metalium backend";
    homepage = "https://github.com/marty1885/llama.cpp";
  };
})

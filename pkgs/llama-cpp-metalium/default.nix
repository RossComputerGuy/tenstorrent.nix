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
  makeWrapper,
}:
(llama-cpp.override { }).overrideAttrs (prevAttrs: {
  pname = "llama-cpp-metalium";
  version = "0-unstable-2026-06-30";

  src = fetchFromGitHub {
    owner = "marty1885";
    repo = "llama.cpp";
    rev = "04602ca95c1a6adb6c1533e024ad9c79ee6c428d";
    hash = "sha256-zUzUb3VJsSOiBM2Zapg0VxV43oABzx3Y9Ez7hivqebE=";
  };

  patches = (prevAttrs.patches or [ ]) ++ [ ./metalium-find-package.patch ];

  postPatch = (prevAttrs.postPatch or "") + ''
    # Redirect the bare "types/arch.hpp" include to the namespaced form; only the
    # latter resolves against tt-metal's installed include dir.
    substituteInPlace \
        ggml/src/ggml-metalium/ggml-metalium.cpp \
        ggml/src/ggml-metalium/metalium-pch.hpp \
      --replace-fail '#include "types/arch.hpp"' '#include "umd/device/types/arch.hpp"'

    # HEAD gates device open on Wormhole only; re-allow Blackhole.
    substituteInPlace ggml/src/ggml-metalium/ggml-metalium.cpp \
      --replace-fail \
        'GGML_ASSERT(device->arch() == tt::ARCH::WORMHOLE_B0);' \
        'GGML_ASSERT(device->arch() == tt::ARCH::WORMHOLE_B0 || device->arch() == tt::ARCH::BLACKHOLE);'

    # Strip a stray local build-tree prefix from a source include.
    substituteInPlace ggml/src/ggml-metalium/ggml-metalium.cpp \
      --replace-fail \
        '#include "build_Release/include/tt-metalium/experimental/tensor/tensor_types.hpp"' \
        '#include "tt-metalium/experimental/tensor/tensor_types.hpp"'
  '';

  npmRoot = null;
  npmDeps = null;
  preConfigure = "";

  nativeBuildInputs =
    builtins.filter (p: !(lib.hasInfix "npm" (p.name or ""))) (prevAttrs.nativeBuildInputs or [ ])
    ++ [
      python3
      makeWrapper
    ];

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
    # Build monolithically (base inherits DL=ON): metalium uses the CPU-backend
    # symbol ggml_get_type_traits_cpu, so as a standalone module its dlopen fails
    # on an undefined symbol and llama silently falls back to CPU.
    (lib.cmakeBool "GGML_BACKEND_DL" false)
  ];

  env = (prevAttrs.env or { }) // {
    TT_METAL_HOME = "${tt-metal}/libexec/tt-metalium";
  };

  # Drop the base postInstall's `llama-server --completion-bash` step: with the
  # backend statically registered it opens a device, which aborts in the sandbox.
  postInstall = ''
    ln -sf $out/bin/llama-cli $out/bin/llama

    mkdir -p $out/include
    cp $src/include/llama.h $out/include/
  '';

  # Bake in the runtime env the backend needs (reg aborts without these).
  # TT_MESH_GRAPH_DESC_PATH is board-specific, so it comes from the NixOS module
  # (hardware.tenstorrent.meshName), not here. --set-default keeps them overridable.
  postFixup =
    let
      ttRoot = "${tt-metal}/libexec/tt-metalium";
    in
    (prevAttrs.postFixup or "")
    + ''
      for exe in $out/bin/*; do
        if [ -f "$exe" ] && [ ! -L "$exe" ]; then
          wrapProgram "$exe" \
            --set-default TT_METAL_HOME "${ttRoot}" \
            --set-default TT_METAL_RUNTIME_ROOT "${ttRoot}"
        fi
      done
    '';

  meta = prevAttrs.meta // {
    description = "llama.cpp with Tenstorrent Metalium backend";
    homepage = "https://github.com/marty1885/llama.cpp";
  };
})

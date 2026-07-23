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

  patches = (prevAttrs.patches or [ ]) ++ [
    ./metalium-find-package.patch
    # Route single-token decode attention through ttnn's
    # scaled_dot_product_attention_decode instead of rejecting it, so generation
    # keeps the KV cache read on device instead of falling back to CPU every token.
    ./flash-attn-decode.patch
  ];

  postPatch = (prevAttrs.postPatch or "") + ''
    # Redirect the bare "types/arch.hpp" include to the namespaced form; only the
    # latter resolves against tt-metal's installed include dir.
    substituteInPlace \
        ggml/src/ggml-metalium/ggml-metalium.cpp \
        ggml/src/ggml-metalium/metalium-pch.hpp \
      --replace-fail '#include "types/arch.hpp"' '#include "umd/device/types/arch.hpp"'

    substituteInPlace ggml/src/ggml-metalium/ggml-metalium.cpp \
      --replace-fail \
        'GGML_ASSERT(device->arch() == tt::ARCH::WORMHOLE_B0);' \
        'GGML_ASSERT(device->arch() == tt::ARCH::WORMHOLE_B0 || device->arch() == tt::ARCH::BLACKHOLE);' \
      --replace-fail \
        'if(arch == tt::ARCH::WORMHOLE_B0) {' \
        'if(arch == tt::ARCH::WORMHOLE_B0 || arch == tt::ARCH::BLACKHOLE) {'

    # Strip a stray local build-tree prefix from a source include.
    substituteInPlace ggml/src/ggml-metalium/ggml-metalium.cpp \
      --replace-fail \
        '#include "build_Release/include/tt-metalium/experimental/tensor/tensor_types.hpp"' \
        '#include "tt-metalium/experimental/tensor/tensor_types.hpp"'

    # The mesh path hardcodes ETH command dispatch, but Blackhole's ethernet RISC
    # can't fit the cq_dispatch/cq_prefetch kernels (idle_erisc code region overflow)
    # and eth dispatch also drags in the harvested-eth-core path. Force Tensix
    # (WORKER) dispatch for the mesh, matching the single-device path.
    substituteInPlace ggml/src/ggml-metalium/ggml-metalium.cpp \
      --replace-fail \
        'trace_region_size, 2, tt::tt_metal::DispatchCoreType::ETH)' \
        'trace_region_size, 2, tt::tt_metal::DispatchCoreType::WORKER)'

    # Finish the fork's half-done SDK port of the RoPE compute kernels. The teardown
    # was already inlined (clear_addr_mod_base() -> TTI_SETC16(2, 0)) but the matching
    # setup still called the removed math::set_addr_mod_base(), which does not compile
    # against tt-metal 0.74 and aborted kernel jit at model warmup. Per tt-llk, that
    # helper is exactly TTI_SETC16(2, 1) (bit 0 = use addr mods 4..7); Blackhole has no
    # symbolic name so tt-llk itself uses the raw instruction, matching the teardown.
    substituteInPlace \
        ggml/src/ggml-metalium/kernels/rope_neox_compute.cpp \
        ggml/src/ggml-metalium/kernels/rope_normal_compute.cpp \
      --replace-fail \
        'math::set_addr_mod_base(); // dst_reg[] addressing below uses addr mods 4..7; dropped in the new-SDK port' \
        'TTI_SETC16(2, 1); // set addr mod base (use addr mods 4..7); inlined for BH, matches TTI_SETC16(2,0) teardown'

    # llama builds the KV cache SET_ROWS index tensors (k_idxs / v_idxs) as I64, but
    # ggml_set_rows also accepts I32 and the Metalium backend only maps integer tensors
    # as I32 (uploaded untiled as UINT32). I64 maps to INVALID, so supports_op rejects
    # the KV cache SET_ROWS and ggml aborts because that cache tensor is pinned to the
    # device buffer. Emit I32 indices instead. The values are KV slot offsets, well
    # within 31 bits for realistic context sizes, and I32 is valid on the CPU fallback.
    substituteInPlace src/llama-kv-cache.cpp \
      --replace-fail \
        'ggml_tensor * k_idxs = ggml_new_tensor_1d(ctx, GGML_TYPE_I64, n_tokens);' \
        'ggml_tensor * k_idxs = ggml_new_tensor_1d(ctx, GGML_TYPE_I32, n_tokens);' \
      --replace-fail \
        'v_idxs = ggml_new_tensor_1d(ctx, GGML_TYPE_I64, n_tokens);' \
        'v_idxs = ggml_new_tensor_1d(ctx, GGML_TYPE_I32, n_tokens);' \
      --replace-fail \
        'v_idxs = ggml_new_tensor_1d(ctx, GGML_TYPE_I64, n_tokens*hparams.n_embd_v_gqa_max());' \
        'v_idxs = ggml_new_tensor_1d(ctx, GGML_TYPE_I32, n_tokens*hparams.n_embd_v_gqa_max());' \
      --replace-fail \
        'int64_t * data = (int64_t *) dst->data;' \
        'int32_t * data = (int32_t *) dst->data;'

    # Drop a leftover debug print in the set_rows path. It fires on every K/V cache
    # write (per layer, per token), flooding stderr and flushing on every call.
    substituteInPlace ggml/src/ggml-metalium/ggml-metalium.cpp \
      --replace-fail \
        'fmt::println("res: {}", res.logical_shape());' \
        ""
  '';

  npmDepsHash = "sha256-0dctM/apI3ysMIEVBaBXO9hZMWskpJpNpOws1gwiOYc=";

  preConfigure = ''
    pushd tools/ui
    LLAMA_BUILD_NUMBER=0 npm run build
    popd
  '';

  nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [
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
            --set-default HOME "/tmp" \
            --set-default TT_METAL_HOME "${ttRoot}" \
            --set-default TT_METAL_RUNTIME_ROOT "${ttRoot}" \
            --set-default GGML_METALIUM_EXPERIMENTAL_OPS "1"
        fi
      done
    '';

  meta = prevAttrs.meta // {
    description = "llama.cpp with Tenstorrent Metalium backend";
    homepage = "https://github.com/marty1885/llama.cpp";
  };
})

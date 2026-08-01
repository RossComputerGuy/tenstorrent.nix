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
    version = "0.75.0";

    src = fetchFromGitHub {
      owner = "tenstorrent";
      repo = "tt-metal";
      tag = "v${finalAttrs.version}";
      fetchSubmodules = true;
      hash = "sha256-FCYdokW0yAKOGQueNGA+BNqSZDvbT8mRIpn3ZXSMT9Q=";
    };

    cpm = fetchurl {
      url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.2/CPM.cmake";
      hash = "sha256-yM3DLAOBZTjOInge1ylk3IZLKjSjENO3EEgSpcotg10=";
    };

    sfpi = callPackage ./sfpi.nix { };

    patches = [
      # ./cadical-local.patch  # PR #46222 merged upstream in 0.75 (applies in reverse)
      ./umd-asio-local.patch
      # https://github.com/tenstorrent/tt-metal/pull/46224
      ./local-find-package.patch
      # ./header-only-local.patch  # PR #46226 merged upstream in 0.75 (applies in reverse)
      # https://github.com/tenstorrent/tt-metal/pull/46229
      ./patched-pins-local.patch
      # tt-umd PR 2187 (./umd-targets-local.patch) merged upstream as of the umd
      # submodule in tt-metal 0.74; dropped (patch now applies in reverse).
      # https://github.com/tenstorrent/tt-metal/issues/49701
      # Drop harvested/nonexistent eth dispatch cores so a 4x p150a mesh can open
      # (the eth dispatch YAML lists cores that don't exist on harvested Blackhole).
      ./bh-eth-dispatch-harvesting.patch
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
            # Cap'n Proto's local-find-package.patch hunks don't apply to 0.74 (block
            # reordered); do them here so CPM finds nixpkgs capnproto offline. (0.74
            # already renames googletest -> GTest upstream, so that rewrite is dropped.)
            substituteInPlace third_party/CMakeLists.txt --replace-fail "NAME capnproto" "NAME CapnProto"
            sed -i 's|^        capnproto_pthread.patch$|&\n    FIND_PACKAGE_ARGUMENTS GLOBAL|' third_party/CMakeLists.txt

            # Disable Tracy's profiler CLI tools + WASM viewer: they pull a GUI/web CPM
            # stack (imgui/glfw/emsdk) and run `emsdk install` at configure. Only
            # TracyClient is needed, and it's built earlier. Wrap csvexport..WASM in
            # if(FALSE), then close it BEFORE the tracy_debug_categories header
            # generation (new in 0.75) so that header is still emitted -- otherwise
            # the compile fails on missing tracy_debug_categories_generated.hpp.
            sed -i '/^add_subdirectory(tracy\/csvexport)$/i if(FALSE) # nix: profiler tools + WASM viewer disabled; TracyClient is built above' tt_metal/third_party/CMakeLists.txt
            sed -i '/^set(_tt_tracy_categories_file /i endif() # nix: end tracy tools/WASM disable; keep the debug-categories header generation below' tt_metal/third_party/CMakeLists.txt

            # The tracy python helper (imported unconditionally by `import ttnn`) does an
            # mkdir of a profiler wasm-trace dir under TT_METAL_HOME at import time. That
            # path lives in the read-only nix store, so the import aborts. Make the mkdir
            # tolerant of a read-only store; profiling still works when TT_METAL_HOME is a
            # writable runtime directory.
            substituteInPlace tools/tracy/common.py \
              --replace-fail 'PROFILER_WASM_TRACES_DIR.mkdir(parents=True, exist_ok=True)' 'try:
          PROFILER_WASM_TRACES_DIR.mkdir(parents=True, exist_ok=True)
      except OSError:
          pass'
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
      # ELFIO is fetched by tt-exalens's nested CPM, which ignores build/_deps;
      # point CPM straight at the source.
      (lib.cmakeFeature "CPM_ELFIO_SOURCE" (builtins.toString deps.elfio))
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
      # The default install ships only a subset of ttnn C++ op headers; the
      # Metalium backend includes many more via two forms (<ttnn/...> from
      # $out/include and <ttnn/cpp/ttnn/...> from libexec). Install the full tree
      # to both roots.
      ( cd ../ttnn/cpp && find ttnn -name '*.hpp' -print0 | while IFS= read -r -d "" h; do
          install -Dm444 "$h" "$out/include/$h"
          install -Dm444 "$h" "$out/libexec/tt-metalium/ttnn/cpp/$h"
        done )

      # ttnn operation kernels (the dataflow/compute sources under any kernels/
      # directory) are JIT-compiled at runtime and resolved by relative path, but
      # TT_INSTALL omits them. Without them ops such as
      # scaled_dot_product_attention abort at model warmup with
      # "Kernel file ttnn/cpp/ttnn/operations/.../reader_interleaved.cpp doesn't
      # exist in any of the searched paths". Ship every file under a ttnn kernels/
      # directory into the libexec ttnn/cpp tree where tt-metal searches.
      ( cd ../ttnn/cpp && find ttnn -path '*/kernels/*' -type f -print0 | while IFS= read -r -d "" k; do
          install -Dm444 "$k" "$out/libexec/tt-metalium/ttnn/cpp/$k"
        done )

      # TT_INSTALL omits several new-in-0.75 compute-kernel API headers under
      # tt_metal/hw/inc/api/compute (e.g. eltwise_unary/lerp.h, snake_beta.h). JIT-compiling any
      # kernel that includes them -- notably the ternary `where` kernel (ternary_sfpu_no_bcast_ttt)
      # -- then fails at runtime with "fatal error: api/compute/eltwise_unary/lerp.h: No such file".
      # Copy the full compute-API tree into the installed hw/inc so every JIT include resolves.
      cp -r --no-preserve=ownership,mode ../tt_metal/hw/inc/api/compute/. \
        $out/libexec/tt-metalium/tt_metal/hw/inc/api/compute/

      mkdir -p $out/${python3.sitePackages}
      cp -r ../ttnn/ttnn $out/${python3.sitePackages}/ttnn
      cp -r ../ttnn/tt_lib $out/${python3.sitePackages}/tt_lib
      cp -r ../tools/tracy $out/${python3.sitePackages}/tracy
      cp $out/lib/_ttnn.so $out/${python3.sitePackages}/ttnn/_ttnn.so

      # The Tenstorrent model library (models.tt_transformers etc.) is not part of
      # the default install, but the vLLM TT plugin loads Llama and friends from it
      # at runtime (models.tt_transformers.tt.generator_vllm). Ship the whole tree so
      # `import models.*` resolves as a namespace package on the python path.
      cp -r ../models $out/${python3.sitePackages}/models
      # Some model demo tests symlink into the repo `tests/` tree, which is not
      # shipped, leaving dangling symlinks that trip the broken-symlink check.
      # Drop them; they are test fixtures, not needed to load a model.
      find $out/${python3.sitePackages}/models -xtype l -delete

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

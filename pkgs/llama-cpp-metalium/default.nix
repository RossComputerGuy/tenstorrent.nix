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
    # The base package inherits GGML_BACKEND_DL=ON, which builds each backend as
    # a standalone module. Metalium calls ggml_get_type_traits_cpu (a CPU-backend
    # symbol) but does not link the CPU module, so dlopen of libggml-metalium.so
    # fails on an undefined symbol and llama silently falls back to CPU. Build
    # monolithically so the symbol resolves and metalium registers statically.
    (lib.cmakeBool "GGML_BACKEND_DL" false)
  ];

  env = (prevAttrs.env or { }) // {
    TT_METAL_HOME = "${tt-metal}/libexec/tt-metalium";
  };

  # The base postInstall runs `llama-server --completion-bash` to generate shell
  # completions. With the backend statically registered, that startup eagerly
  # calls ttnn::open_mesh_device (ggml-metalium.cpp), which aborts in the
  # deviceless Nix sandbox. Drop the completion step; keep the rest.
  postInstall = ''
    ln -sf $out/bin/llama-cli $out/bin/llama

    mkdir -p $out/include
    cp $src/include/llama.h $out/include/
  '';

  # ggml_backend_metalium_reg aborts unless TT_METAL_HOME is set at runtime, and
  # tt-metal needs it to locate its kernels. Bake it into every executable.
  postFixup = (prevAttrs.postFixup or "") + ''
    for exe in $out/bin/*; do
      if [ -f "$exe" ] && [ ! -L "$exe" ]; then
        wrapProgram "$exe" --set-default TT_METAL_HOME "${tt-metal}/libexec/tt-metalium"
      fi
    done
  '';

  meta = prevAttrs.meta // {
    description = "llama.cpp with Tenstorrent Metalium backend";
    homepage = "https://github.com/marty1885/llama.cpp";
  };
})

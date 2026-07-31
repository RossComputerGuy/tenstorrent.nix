{
  lib,
  stdenvNoCC,
  python3,
  python3Packages,
  tt-metal,
  makeWrapper,
}:
let
  # The serving stack runs on tt-metal's python bindings, so the interpreter must
  # match the one tt-metal was built against (nixpkgs default).
  ttm = tt-metal;

  pyEnv = python3.withPackages (
    ps:
    with ps;
    [
      vllm-tt
      vllm-tt-plugin
    ]
    # ttnn imports these at runtime but they are not part of the vLLM closure.
    ++ [
      loguru
      pyyaml
      click
      networkx
      tabulate
      graphviz
      pydantic
      pandas
      seaborn
      matplotlib
      pytest
    ]
  );
in
stdenvNoCC.mkDerivation {
  pname = "tt-vllm-server";
  inherit (ttm) version;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    # `vllm serve` with the TT platform plugin enabled and tt-metal on the path.
    # MESH_DEVICE defaults to a single p150; the NixOS module overrides it (e.g.
    # P150x4 for a four-card mesh). Everything is --set-default so the service or
    # the operator can override without rebuilding.
    makeWrapper ${pyEnv}/bin/vllm $out/bin/tt-vllm-serve \
      --set-default HOME /tmp \
      --set-default TT_METAL_HOME ${ttm}/libexec/tt-metalium \
      --set-default TT_METAL_RUNTIME_ROOT ${ttm}/libexec/tt-metalium \
      --set-default VLLM_USE_V1 1 \
      --set-default VLLM_PLUGINS tt,tt_model_registry \
      --set-default MESH_DEVICE P150 \
      --prefix PYTHONPATH : ${ttm}/${python3.sitePackages}
    runHook postInstall
  '';

  passthru = {
    python = pyEnv;
  };

  meta = {
    description = "vLLM OpenAI server wired to run on Tenstorrent hardware via tt-metal";
    homepage = "https://github.com/tenstorrent/vllm";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "tt-vllm-serve";
  };
}

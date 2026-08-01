{
  lib,
  stdenvNoCC,
  python3,
  tt-metal,
  makeWrapper,
  fetchFromGitHub,
  coreutils,
}:
let
  # Like tt-vllm-server, the runner uses tt-metal's python bindings, so the
  # interpreter must match the one tt-metal was built against.
  ttm = tt-metal;

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = "tt-inference-server";
    rev = "872bbdf6563db2c66c4cff7a37b10df218a9b406";
    hash = "sha256-rJ7rxYk1xjdL+51RIgH1ocvNfg6yQjvWTaBn6ZMUx2o=";
  };

  pyEnv = python3.withPackages (
    ps:
    with ps;
    [
      # tt-media-server core (requirements.txt; asyncio is stdlib)
      aiohttp
      colorama
      fastapi
      faster-fifo
      httpx
      huggingface-hub
      imageio-ffmpeg
      loguru
      prometheus-client
      prometheus-fastapi-instrumentator
      psutil
      pydantic-settings
      python-multipart
      tqdm
      uvicorn
      requests
      num2words
    ]
    # Audio IO for the Whisper runner (datasets 4.x decodes via torchcodec).
    ++ [
      scipy
      soundfile
      librosa
      torchcodec
    ]
    # The tt-metal Whisper demo/runner path pulls these at runtime; tracy needs
    # seaborn/pandas/matplotlib and the runner imports (at module load) pytest +
    # torchvision/datasets/opencv/pillow/pytz/jiwer/evaluate.
    ++ [
      torch
      torchvision
      transformers
      datasets
      numpy
      pytest
      pytest-asyncio
      jiwer
      evaluate
      opencv4
      pillow
      pytz
      seaborn
      pandas
      matplotlib
      graphviz
      networkx
      tabulate
      pydantic
    ]
  );
in
stdenvNoCC.mkDerivation {
  pname = "tt-media-server";
  inherit (ttm) version;
  inherit src;
  sourceRoot = "${src.name}/tt-media-server";

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/tt-media-server $out/bin
    cp -r . $out/libexec/tt-media-server/

    # tt-metal compiles dispatch kernels into $TT_METAL_HOME/built and writes
    # generated/ under the cwd, but both point at the read-only nix store. The
    # tt-metal package expects TT_METAL_HOME to be a WRITABLE runtime directory.
    # The launcher builds a symlink-farm of tt-metalium and a writable copy of
    # the app tree in a state dir (default under XDG cache), idempotently, then
    # runs uvicorn from there. MODEL_RUNNER/device defaults target Tier-1 Whisper
    # on a single Blackhole p150; all are overridable from the environment.
    cat > $out/bin/tt-media-serve <<EOF
    #!${stdenvNoCC.shell}
    set -eu
    export PATH=${coreutils}/bin:\$PATH

    STATE="\''${TT_MEDIA_STATE_DIR:-\''${XDG_CACHE_HOME:-\$HOME/.cache}/tt-media-server}"
    HOME_FARM="\$STATE/tt-metal-home"
    RUN="\$STATE/run"

    if [ ! -e "\$HOME_FARM/.farm-ok" ]; then
      rm -rf "\$HOME_FARM"
      mkdir -p "\$HOME_FARM"
      cp -rs ${ttm}/libexec/tt-metalium/. "\$HOME_FARM/"
      chmod -R u+w "\$HOME_FARM"
      touch "\$HOME_FARM/.farm-ok"
    fi
    if [ ! -e "\$RUN/.run-ok" ]; then
      rm -rf "\$RUN"
      mkdir -p "\$RUN"
      cp -r $out/libexec/tt-media-server/. "\$RUN/"
      chmod -R u+w "\$RUN"
      touch "\$RUN/.run-ok"
    fi

    export TT_METAL_HOME="\''${TT_METAL_HOME:-\$HOME_FARM}"
    export TT_METAL_RUNTIME_ROOT="\''${TT_METAL_RUNTIME_ROOT:-\$HOME_FARM}"
    export MODEL_RUNNER="\''${MODEL_RUNNER:-tt-whisper}"
    export MODEL="\''${MODEL:-distil-large-v3}"
    export DEVICE="\''${DEVICE:-p150}"
    export IS_GALAXY="\''${IS_GALAXY:-false}"
    export DEVICE_IDS="\''${DEVICE_IDS:-(0)}"
    export ALLOW_AUDIO_PREPROCESSING="\''${ALLOW_AUDIO_PREPROCESSING:-false}"
    export DOWNLOAD_WEIGHTS_FROM_SERVICE="\''${DOWNLOAD_WEIGHTS_FROM_SERVICE:-false}"
    export PYTHONPATH="\$RUN:${ttm}/${python3.sitePackages}\''${PYTHONPATH:+:\$PYTHONPATH}"

    cd "\$RUN"
    exec ${pyEnv}/bin/python3 -m uvicorn main:app \
      --host "\''${TT_MEDIA_HOST:-127.0.0.1}" \
      --port "\''${TT_MEDIA_PORT:-8000}" "\$@"
    EOF
    chmod +x $out/bin/tt-media-serve

    runHook postInstall
  '';

  passthru = {
    python = pyEnv;
  };

  meta = {
    description = "Tenstorrent tt-media-server (Whisper speech-to-text) wired to run natively on tt-metal";
    homepage = "https://github.com/tenstorrent/tt-inference-server";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "tt-media-serve";
  };
}

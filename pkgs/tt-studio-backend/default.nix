{
  lib,
  stdenvNoCC,
  python312,
  fetchFromGitHub,
  makeWrapper,
}:
let
  python = python312;
  pyEnv = python.withPackages (
    ps: with ps; [
      # web stack
      django
      djangorestframework
      django-cors-headers
      channels
      uvicorn
      gunicorn
      httpx
      requests
      pyjwt
      psutil
      # docker-py is imported at boot (logs_control) but no daemon is needed
      docker
      # documents
      pypdf
      python-docx
      markdown
      beautifulsoup4
      # RAG stack (loaded at boot via INSTALLED_APPS; the cloud chat path does not
      # exercise it, but the modules must import)
      chromadb
      sentence-transformers
      onnxruntime
      langchain
      langchain-core
      langchain-chroma
      langchain-text-splitters
    ]
  );
in
stdenvNoCC.mkDerivation {
  pname = "tt-studio-backend";
  version = "0.0.1-unstable-2026-07-30";

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = "tt-studio";
    rev = "8d622a0a69be48700f47ecb80a82f299a397f1e4";
    hash = "sha256-BHQZZmqWx9Wzx5VeJnqPYHs6ALbUljth4EV+Kpa6H8Y=";
  };
  sourceRoot = "source/app/backend";

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/tt-studio-backend
    cp -r . $out/share/tt-studio-backend/

    # `wakeword_control` imports `openwakeword` at boot (an undeclared dependency
    # that is not in nixpkgs and is unused by the cloud chat path). Ship a stub so
    # the ASGI app loads; instantiating the model raises, but that only happens if
    # someone uses the wake-word feature.
    mkdir -p $out/lib/stubs/openwakeword
    : > $out/lib/stubs/openwakeword/__init__.py
    cat > $out/lib/stubs/openwakeword/model.py <<'EOF'
    class Model:
        def __init__(self, *a, **k):
            raise RuntimeError("openwakeword is stubbed out; wake-word is disabled in this deployment")
    EOF

    mkdir -p $out/bin
    # manage.py entry point, e.g. for migrations.
    makeWrapper ${pyEnv}/bin/python $out/bin/tt-studio-manage \
      --add-flags "$out/share/tt-studio-backend/manage.py" \
      --prefix PYTHONPATH : "$out/lib/stubs" \
      --set-default DJANGO_SETTINGS_MODULE api.settings

    # ASGI server entry point.
    makeWrapper ${pyEnv}/bin/uvicorn $out/bin/tt-studio-backend \
      --chdir "$out/share/tt-studio-backend" \
      --prefix PYTHONPATH : "$out/lib/stubs" \
      --set-default DJANGO_SETTINGS_MODULE api.settings \
      --add-flags "api.asgi:application"
    runHook postInstall
  '';

  passthru = {
    python = pyEnv;
  };

  meta = {
    description = "tt-studio Django backend (cloud/vLLM path), native, no Docker";
    homepage = "https://github.com/tenstorrent/tt-studio";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}

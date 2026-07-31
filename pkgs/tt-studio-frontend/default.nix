{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_22,
  servedModelName ? "meta-llama/Llama-3.1-8B-Instruct",
  defaultMaxTokens ? 4096,
}:
buildNpmPackage {
  pname = "tt-studio-frontend";
  version = "2.0.1-unstable-2026-07-30";

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = "tt-studio";
    rev = "8d622a0a69be48700f47ecb80a82f299a397f1e4";
    hash = "sha256-BHQZZmqWx9Wzx5VeJnqPYHs6ALbUljth4EV+Kpa6H8Y=";
  };
  sourceRoot = "source/app/frontend";

  npmDepsHash = "sha256-rVKqh2vVfE3czFs2NISQfKZ1TEnQkurkfISbyn+mFP0=";

  nodejs = nodejs_22;

  # Route the chat UI through the cloud path (/models-api/inference_cloud/), which
  # streams straight to an external OpenAI-compatible server. This is what lets the
  # console talk to the native vLLM server without Docker.
  env.VITE_ENABLE_DEPLOYED = "true";

  # In deployed mode the UI hardcodes a model id in the request body. Point it at
  # the model this deployment actually serves. Also lift the default max-tokens:
  # 1024 is too small for a reasoning model (Qwen3.6 spends that many tokens just
  # thinking and never emits the answer, so the chat looks empty). The slider
  # ceiling is already 131072, this only changes the default.
  postPatch = ''
    substituteInPlace src/components/chatui/runInference.ts \
      --replace-fail 'meta-llama/Llama-3.3-70B-Instruct' '${servedModelName}'
    substituteInPlace src/components/chatui/Settings.tsx \
      --replace-fail 'maxLength: 1024,' 'maxLength: ${toString defaultMaxTokens},'
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r dist $out/dist
    runHook postInstall
  '';

  meta = {
    description = "tt-studio web console frontend (static build), wired for the native vLLM cloud path";
    homepage = "https://github.com/tenstorrent/tt-studio";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}

{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  setuptools-scm,
  wheel,
  packaging,
  jinja2,
  torch,
  vllm,
}:
buildPythonPackage {
  pname = "vllm-tt";
  version = "0.16.0-tt-unstable-2026-07-30";
  pyproject = true;

  # Tenstorrent's vLLM fork. The `dev` branch carries the TT platform plugin and
  # tracks tt-metal; there are no release tags, so pin the commit that pairs with
  # tt-metal 0.75.0.
  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = "vllm";
    rev = "50d3f5ff4d0293ecb607c76e72529da5f00cc9bf";
    hash = "sha256-Kbq6JaRKe5C2XVEMMXhK7RTz+ekvNZRL35ZbYWpWrdM=";
  };

  # The fork builds a pure-python vLLM with the `empty` device target: no CUDA, no
  # CPU kernels, no C++ compilation. The `tt` platform is injected at runtime by
  # vllm-tt-plugin. This is why the derivation needs no compiler or cmake step.
  env = {
    VLLM_TARGET_DEVICE = "empty";
    # The fork uses setuptools-scm with no tags; fetchFromGitHub drops .git, so give
    # it the base version directly.
    SETUPTOOLS_SCM_PRETEND_VERSION = "0.16.0";
  };
  dontUseCmakeConfigure = true;

  # The empty target compiles nothing, so drop the build pins meant for kernel
  # builds (cmake, ninja, an exact torch, grpc codegen). setup.py still imports
  # torch at module load, so torch stays in the build inputs below.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail '"cmake>=3.26.1",' "" \
      --replace-fail '"ninja",' "" \
      --replace-fail '"torch == 2.10.0",' "" \
      --replace-fail '"grpcio-tools==1.78.0",' ""
  '';

  build-system = [
    setuptools
    setuptools-scm
    wheel
    packaging
    jinja2
    torch
  ];

  # Reuse the resolved python dependency closure from nixpkgs' vLLM (same 0.16.0
  # base) instead of re-deriving it. The CPU variant drops the CUDA-only extras.
  dependencies = (vllm.override {
    cudaSupport = false;
    rocmSupport = false;
  }).dependencies;

  # vLLM pins exact versions that do not all match nixpkgs; the fork is tested
  # against a nearby set and the tt path does not exercise the drift.
  dontCheckRuntimeDeps = true;

  pythonImportsCheck = [ "vllm" ];

  meta = {
    description = "Tenstorrent vLLM fork (pure-python empty target) for TT hardware serving";
    homepage = "https://github.com/tenstorrent/vllm";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}

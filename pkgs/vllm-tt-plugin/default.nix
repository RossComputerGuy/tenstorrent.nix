{
  lib,
  buildPythonPackage,
  setuptools,
  tblib,
  vllm-tt,
}:
buildPythonPackage {
  pname = "vllm-tt-plugin";
  version = "0.0.0";
  pyproject = true;

  # Same source tree as vllm-tt; the plugin lives in a subdirectory.
  src = vllm-tt.src;
  sourceRoot = "${vllm-tt.src.name}/plugins/vllm-tt-plugin";

  build-system = [ setuptools ];

  # The only declared runtime dependency. vLLM and torch come from vllm-tt, and
  # ttnn plus the model library come from the tt-metal runtime, so they are not
  # listed here.
  dependencies = [ tblib ];

  dontCheckRuntimeDeps = true;

  pythonImportsCheck = [ "vllm_tt_plugin" ];

  meta = {
    description = "vLLM platform plugin that runs models on Tenstorrent hardware";
    homepage = "https://github.com/tenstorrent/vllm/tree/dev/plugins/vllm-tt-plugin";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}

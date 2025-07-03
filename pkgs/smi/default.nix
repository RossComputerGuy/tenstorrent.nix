{
  lib,
  buildPythonApplication,
  fetchFromGitHub,
  fetchpatch,
  setuptools,
  distro,
  elasticsearch,
  pydantic,
  pyluwen,
  rich,
  textual,
  pre-commit,
  importlib-resources,
  tools-common,
}:
buildPythonApplication rec {
  pname = "tt-smi";
  version = "3.0.21";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-6LWx/KkOOAG+dqN0idfY2/ehyUSq5gJpL151pthBXgU=";
  };

  patches = [
    (fetchpatch {
      url = "https://github.com/RossComputerGuy/tt-smi/commit/f44623b69050eeafc278348549083810c0972295.patch";
      hash = "sha256-6qZ/LHf/SiVNyp4Eit696hCj39jrqHKopcWBwA5SKKU=";
    })
  ];

  build-system = [
    setuptools
  ];

  dependencies = [
    distro
    elasticsearch
    pydantic
    pyluwen
    rich
    textual
    pre-commit
    importlib-resources
    tools-common
    setuptools
  ];

  # Fails due to having no tests
  dontUsePytestCheck = true;

  meta = {
    description = "Tenstorrent console based hardware information program";
    homepage = "https://github.com/tenstorrent/tt-smi";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ asl20 ];
  };
}

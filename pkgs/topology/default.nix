{
  lib,
  buildPythonApplication,
  fetchFromGitHub,
  fetchpatch,
  setuptools,
  black,
  elasticsearch,
  pydantic,
  pyluwen,
  tools-common,
  pre-commit,
  networkx,
  matplotlib,
}:
buildPythonApplication rec {
  pname = "tt-topology";
  version = "1.2.11";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-DX0jF41JwJuEPiWfE5PckR1UnOjF8avOM7Mi5/8nNqE=";
  };

  patches = [
    (fetchpatch {
      url = "https://github.com/RossComputerGuy/tt-topology/commit/2762db1d7758639e50da6a18bb17a8965813807b.patch";
      hash = "sha256-l64w8db6s8ihT41Nz+KW9ohTbvet7oPd3daSSO9SCWc=";
    })
  ];

  build-system = [
    setuptools
  ];

  dependencies = [
    black
    elasticsearch
    pydantic
    pyluwen
    tools-common
    pre-commit
    networkx
    matplotlib
    setuptools
  ];

  # Tests are broken
  dontUsePytestCheck = true;

  meta = {
    description = "Command line utility used to flash multiple NB cards on a system to use specific eth routing configurations.";
    homepage = "https://github.com/tenstorrent/tt-topology";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ asl20 ];
  };
}

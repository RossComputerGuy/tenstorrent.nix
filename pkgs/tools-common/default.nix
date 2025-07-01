{
  lib,
  buildPythonApplication,
  fetchpatch,
  fetchFromGitHub,
  setuptools,
  distro,
  elasticsearch,
  psutil,
  pyyaml,
  rich,
  textual,
  requests,
  tqdm,
  pydantic,
}:
buildPythonApplication rec {
  pname = "tt-tools-common";
  version = "1.4.16";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-P1cdRqQOOzz9Ax+SqJl5mS1wjZGSBS5tXnaWD1qRNHo=";
  };

  patches = [
    (fetchpatch {
      url = "https://github.com/danieldegrasse/tt-tools-common/commit/6ef07e64132262a40507aeb613c0de3d94b05bfe.patch";
      hash = "sha256-uPWQMG9pRsC37NPkkZ6h8JWpj/3FuIZk40XKmTW7VRE=";
    })
  ];

  build-system = [
    setuptools
  ];

  dependencies = [
    distro
    elasticsearch
    psutil
    pyyaml
    rich
    textual
    requests
    tqdm
    pydantic
  ];

  meta = {
    description = "This is a space for common utilities shared across Tentorrent tools. This is a helper library and not a standalone tool.";
    homepage = "https://github.com/tenstorrent/tt-tools-common";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ asl20 ];
  };
}

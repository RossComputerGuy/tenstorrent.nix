{
  lib,
  buildPythonApplication,
  fetchFromGitHub,
  setuptools,
  jsons,
  pyluwen,
  tools-common,
}:
buildPythonApplication rec {
  pname = "tt-burnin";
  version = "0.2.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-hDaQhqS3Wbf7blJxrQZzXYq087W7juuu+RT5ZdMjQw0=";
  };

  build-system = [
    setuptools
  ];

  dependencies = [
    pyluwen
    tools-common
    jsons
  ];

  meta = {
    description = "Command line utility to run a high power consumption workload on TT devices.";
    homepage = "https://github.com/tenstorrent/tt-burnin";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ asl20 ];
  };
}

{
  lib,
  buildPythonApplication,
  fetchFromGitHub,
  fetchpatch,
  setuptools,
  pyyaml,
  tabulate,
  pyluwen,
  tools-common,
}:
buildPythonApplication rec {
  pname = "tt-flash";
  version = "3.3.5";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = pname;
    tag = "v${version}";
    hash = "sha256-6NPB8Kf6pCeP2aPL9DxKklG96rRMOSaqi4RSZ989jv0=";
  };

  patches = [
    (fetchpatch {
      url = "https://github.com/RossComputerGuy/tt-flash/commit/1c5d502c4c4f35858952ced2954e87e20c134a9c.patch";
      hash = "sha256-CEe6y1VQ29tTrKT0T2JOGnPSg9oEhi18MyPobssdDbE=";
    })
  ];

  build-system = [
    setuptools
  ];

  dependencies = [
    tabulate
    pyyaml
    pyluwen
    tools-common
  ];

  meta = {
    description = "Tenstorrent Firmware Update Utility";
    homepage = "https://github.com/tenstorrent/tt-flash";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ asl20 ];
  };
}

{
  lib,
  buildPythonApplication,
  runCommand,
  fetchFromGitHub,
  rustPlatform,
  maturin,
  protobuf,
}:
buildPythonApplication rec {
  pname = "pyluwen";
  version = "0.7.10";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = "luwen";
    tag = "v${version}";
    hash = "sha256-zhj4e6pRuCYLUYMWCcmPVIZbe3cUitHi3VzprSi/oqA=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    hash = "sha256-j0So1lGg39qvi39FBDSQn6advxlilS6CAqTuWl979lE=";
  };

  sourceRoot = "${src.name}/crates/${pname}";

  patches = [
    ../luwen/fix-pcie65.patch
  ];

  prePatch = ''
    chmod -R u+w ../../
    cd ../../
  '';

  postPatch = ''
    cd ../$sourceRoot
    cp --no-preserve=ownership,mode ../../Cargo.lock .
  '';

  nativeBuildInputs = with rustPlatform; [
    cargoSetupHook
    maturinBuildHook
    protobuf
  ];

  build-system = [ maturin ];

  meta = {
    description = "Tenstorrent system interface library";
    homepage = "https://github.com/tenstorrent/luwen";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ asl20 ];
  };
}

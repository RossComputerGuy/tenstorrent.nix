{
  lib,
  rustPlatform,
  fetchFromGitHub,
  protobuf,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "luwen";
  version = "0.7.10";

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = finalAttrs.pname;
    tag = "v${finalAttrs.version}";
    hash = "sha256-zhj4e6pRuCYLUYMWCcmPVIZbe3cUitHi3VzprSi/oqA=";
  };

  nativeBuildInputs = [
    protobuf
  ];

  patches = [
    ./fix-pcie65.patch
  ];

  cargoHash = "sha256-j0So1lGg39qvi39FBDSQn6advxlilS6CAqTuWl979lE=";

  meta = {
    description = "Tenstorrent system interface library";
    homepage = "https://github.com/tenstorrent/luwen";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ asl20 ];
  };
})

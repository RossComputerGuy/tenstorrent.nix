{
  lib,
  buildPythonPackage,
  runCommand,
  fetchFromGitHub,
  rustPlatform,
  maturin,
  protobuf_30,
}:
buildPythonPackage rec {
  pname = "pyluwen";
  version = "0.8.5";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = "luwen";
    tag = "v${version}";
    hash = "sha256-lY7cZ+8C0UEGGYxufl4Vi8g0L4AJFXaGqn7XE2ivTcQ=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    hash = "sha256-QBGXbRiBk4WIQFopq1OccmUHgx5GzR/PKhMH4Ie+fyg=";
  };

  sourceRoot = "${src.name}/bind/${pname}";

  prePatch = ''
    chmod -R u+w ../../
    cd ../../
  '';

  postPatch = ''
    cd ../$sourceRoot
    cp --no-preserve=ownership,mode ../../Cargo.lock .
    sed -i '0,/version = /{s/version = "*.*.*"/version = "${version}"/g}' Cargo.toml
  '';

  nativeBuildInputs = with rustPlatform; [
    cargoSetupHook
    maturinBuildHook
    protobuf_30
  ];

  build-system = [ maturin ];

  meta = {
    description = "Tenstorrent system interface library";
    homepage = "https://github.com/tenstorrent/luwen";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ asl20 ];
  };
}

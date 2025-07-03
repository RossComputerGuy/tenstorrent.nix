{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  smi,
  pstree,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "tt-system-tools";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = finalAttrs.pname;
    tag = "v${finalAttrs.version}";
    hash = "sha256-qDyhXigfd9SGQDZjYN/0lMrY+CSXtLH3kjC3Q3GWmME=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    install -Dm755 tt-oops/tt-oops.sh $out/bin/tt-oops
    wrapProgram "$out/bin/tt-oops" \
      --prefix PATH : ${
        lib.makeBinPath [
          smi
          pstree
        ]
      }
  '';

  meta = {
    description = "System tools for Tenstorrent cards";
    homepage = "https://github.com/tenstorrent/tt-system-tools";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ asl20 ];
  };
})

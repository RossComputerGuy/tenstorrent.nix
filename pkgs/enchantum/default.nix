{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "enchantum";
  version = "0-unstable-2026-04-23";

  src = fetchFromGitHub {
    owner = "ZXShady";
    repo = "enchantum";
    rev = "8ca5b0eb7e7ebe0252e5bc6915083f1dd1b8294e";
    hash = "sha256-q2bbNAMpNJYedekEDtTQ2qI2+GPdkTsuxAHCBaAnuTA=";
  };

  nativeBuildInputs = [
    cmake
    ninja
  ];

  postInstall = ''
    mv $out/cmake/*.cmake $out/share/enchantum/cmake/
    rmdir $out/cmake
  '';

  meta = {
    description = "Modern C++20 compile time enum reflection library";
    homepage = "https://github.com/ZXShady/enchantum";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ mit ];
  };
})

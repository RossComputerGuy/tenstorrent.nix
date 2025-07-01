{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "tt-kmd";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "tenstorrent";
    repo = finalAttrs.pname;
    tag = "ttkmd-${finalAttrs.version}";
    hash = "sha256-Y85857oWzsltRyRWpK8Wi0H38mBFwqM3+iXkwVK4DPY=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  buildFlags = [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    install -D tenstorrent.ko $out/lib/modules/${kernel.modDirVersion}/extra/tensorrent.ko
    mkdir -p $out/lib/udev/rules.d
    cp udev-50-tenstorrent.rules $out/lib/udev/rules.d/50-tenstorrent.rules
  '';

  meta = {
    description = "Tenstorrent Kernel Module";
    homepage = "https://tenstorrent.com";
    maintainers = with lib.maintainers; [ RossComputerGuy ];
    license = with lib.licenses; [ gpl2Only ];
    platforms = lib.platforms.linux;
  };
})

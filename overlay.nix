final: prev: {
  enchantum = final.callPackage ./pkgs/enchantum { };
  llama-cpp-metalium = final.callPackage ./pkgs/llama-cpp-metalium { };
  luwen = final.callPackage ./pkgs/luwen { };
  xtensor-blas = prev.xtensor-blas.overrideAttrs (prevAttrs: {
    postFixup = (prevAttrs.postFixup or "") + ''
      sed -i "s|\''${PACKAGE_PREFIX_DIR}//nix/store|/nix/store|g" $out/lib/cmake/xtensor-blas/xtensor-blasConfig.cmake
    '';
  });
  nanobench = prev.nanobench.overrideAttrs (prevAttrs: {
    patches = (prevAttrs.patches or [ ]) ++ [ ./pkgs/nanobench/fix-cmake-find_package.patch ];
  });
  tt-burnin = final.callPackage ./pkgs/tt-burnin { };
  tt-logger = final.callPackage ./pkgs/tt-logger { };
  tt-metal = final.callPackage ./pkgs/tt-metal { };
  tt-smi = final.callPackage ./pkgs/tt-smi { };
  tt-system-tools = final.callPackage ./pkgs/tt-system-tools { };
  tt-topology = final.callPackage ./pkgs/tt-topology { };
  tt-umd = final.callPackage ./pkgs/tt-umd { };

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: pyprev: {
      pyluwen = pyfinal.callPackage ./pkgs/pyluwen { };
      tt-flash = pyfinal.callPackage ./pkgs/tt-flash { };
      tt-tools-common = pyfinal.callPackage ./pkgs/tt-tools-common { };
    })
  ];

  linuxKernel = prev.linuxKernel // {
    packagesFor =
      kernel:
      (prev.linuxKernel.packagesFor kernel).extend (
        lpfinal: lpprev: {
          tt-kmd = lpfinal.callPackage ./pkgs/tt-kmd { };
        }
      );
  };
}

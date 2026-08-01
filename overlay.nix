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
  tt-vllm-server = final.callPackage ./pkgs/tt-vllm-server { };
  tt-studio-frontend = final.callPackage ./pkgs/tt-studio-frontend { };
  tt-studio-backend = final.callPackage ./pkgs/tt-studio-backend { };
  tt-smi = final.callPackage ./pkgs/tt-smi { };
  tt-system-tools = final.callPackage ./pkgs/tt-system-tools { };
  tt-topology = final.callPackage ./pkgs/tt-topology { };
  tt-umd = final.callPackage ./pkgs/tt-umd { };

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: pyprev: {
      pyluwen = pyfinal.callPackage ./pkgs/pyluwen { };
      tt-flash = pyfinal.callPackage ./pkgs/tt-flash { };
      tt-tools-common = pyfinal.callPackage ./pkgs/tt-tools-common { };
      vllm-tt = pyfinal.callPackage ./pkgs/vllm-tt { };
      vllm-tt-plugin = pyfinal.callPackage ./pkgs/vllm-tt-plugin { };

      # This vLLM dependency pins starlette<1.0.0, but newer nixpkgs ship starlette
      # 1.x. The cap is conservative (it works on 1.x), so relax it rather than let
      # the runtime-deps check fail the whole vLLM closure.
      prometheus-fastapi-instrumentator =
        pyprev.prometheus-fastapi-instrumentator.overridePythonAttrs
          (old: {
            pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "starlette" ];
          });

      # The Tenstorrent vLLM fork imports `ReasoningEffort` from mistral-common,
      # which older nixpkgs pins lack. Bump to 1.11.2 (which has it) so the fork
      # loads regardless of the host nixpkgs' mistral-common version.
      mistral-common = pyprev.mistral-common.overridePythonAttrs (old: {
        version = "1.11.2";
        src = final.fetchFromGitHub {
          owner = "mistralai";
          repo = "mistral-common";
          tag = "v1.11.2";
          hash = "sha256-EXdZcBR61GNye8LqwIqRO8lP1lK6fqPJufWFO9XkkYQ=";
        };
        # The bumped source keeps the older derivation's check inputs, and 1.11.2's
        # test suite pulls in llguidance which is not available here. We only need
        # the library to import, not its tests.
        doCheck = false;
      });
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

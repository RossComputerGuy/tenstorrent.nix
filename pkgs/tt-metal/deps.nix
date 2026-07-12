{
  fetchFromGitHub,
  fetchzip,
  applyPatches,
  tt-metal-src,
}:
let
  patchDir = "${tt-metal-src}/third_party";
in
{
  boost = fetchzip {
    url = "https://github.com/boostorg/boost/releases/download/boost-1.86.0/boost-1.86.0-cmake.tar.xz";
    hash = "sha256-8Ra5VNQUpd29u3oHMmP6V2JQtvJJz2D+E33HPi+L6uA=";
  };
  protobuf = applyPatches {
    src = fetchFromGitHub {
      owner = "protocolbuffers";
      repo = "protobuf";
      tag = "v21.12";
      hash = "sha256-VZQEFHq17UsTH5CZZOcJBKiScGV2xPJ/e6gkkVliRCU=";
    };
    patches = [ "${patchDir}/protobuf_noreturn.patch" ];
  };
  reflect = fetchFromGitHub {
    owner = "boost-ext";
    repo = "reflect";
    tag = "v1.2.6";
    hash = "sha256-qjy5KyAm7/WeCyxMu/5QrBVjDSJPs0q/ZPyQwXp0WLA=";
  };
  nanobind = fetchFromGitHub {
    owner = "wjakob";
    repo = "nanobind";
    rev = "c5a3a378aa61d104c82ca053cb1e367782cd3618";
    fetchSubmodules = true;
    hash = "sha256-io44YhN+VpfHFWyvvLWSanRgbzA0whK8WlDNRi3hahU=";
  };
  taskflow = fetchFromGitHub {
    owner = "taskflow";
    repo = "taskflow";
    tag = "v3.7.0";
    hash = "sha256-q2IYhG84hPIZhuogWf6ojDG9S9ZyuJz9s14kQyIc6t0=";
  };
  libdwarf = fetchFromGitHub {
    owner = "davea42";
    repo = "libdwarf-code";
    tag = "v2.3.1";
    hash = "sha256-azVCzQt9oA40YACa9PkdNt0D8vWRNHXXGoSFOYNJxgA=";
  };
  flatbuffers = fetchFromGitHub {
    owner = "google";
    repo = "flatbuffers";
    tag = "v24.3.25";
    hash = "sha256-uE9CQnhzVgOweYLhWPn2hvzXHyBbFiFVESJ1AEM3BmA=";
  };
  cadical = applyPatches {
    src = fetchFromGitHub {
      owner = "arminbiere";
      repo = "cadical";
      tag = "rel-2.2.1";
      hash = "sha256-dYRaw9DI63Nqz0IJkfQYU4y00KSfq1Xv0xZuL1G15CY=";
    };
    patches = [ "${patchDir}/cadical_vivify_include_tuple.patch" ];
  };
  nanomsg = fetchFromGitHub {
    owner = "nanomsg";
    repo = "nng";
    tag = "v1.8.0";
    hash = "sha256-E2uosZrmxO3fqwlLuu5e36P70iGj5xUlvhEb+1aSvOA=";
  };
  libuv = fetchFromGitHub {
    owner = "libuv";
    repo = "libuv";
    tag = "v1.51.0";
    hash = "sha256-ayTk3qkeeAjrGj5ab7wF7vpWI8XWS1EeKKUqzaD/LY0=";
  };
  cxxopts = fetchFromGitHub {
    owner = "jarro2783";
    repo = "cxxopts";
    rev = "dbf4c6a66816f6c3872b46cc6af119ad227e04e1";
    hash = "sha256-2Z8DT9ihlmbiqCi8gcNzW4C5AUh4xCrpCKrGbRYcreQ=";
  };
  nanobench = fetchFromGitHub {
    owner = "martinus";
    repo = "nanobench";
    tag = "v4.3.11";
    hash = "sha256-6OoVU31cNY0pIYpK/PdB9Qej+9IJo7+fHFQCTymBVrk=";
  };
  umd_asio = fetchFromGitHub {
    owner = "chriskohlhoff";
    repo = "asio";
    tag = "asio-1-30-2";
    hash = "sha256-g+ZPKBUhBGlgvce8uTkuR983unD2kbQKgoddko7x+fk=";
  };
  tracy = fetchFromGitHub {
    owner = "tenstorrent";
    repo = "tracy";
    rev = "0aaefbb689b4c60694edc905545fc4709fd13f6a";
    hash = "sha256-hnWNjkvrQ/uDdULhhB87OLVeHiS7zseY1+7or7F35uU=";
  };
  ttexalens = fetchFromGitHub {
    owner = "tenstorrent";
    repo = "tt-exalens";
    rev = "6f5720240b7254b25cb3d78aef81769fc12a30f9";
    hash = "sha256-QX9fh4KPJEj4AQjDViPQgVW1JxOADWJk0SlASLJTUCY=";
  };
  elfio = fetchFromGitHub {
    owner = "serge1";
    repo = "ELFIO";
    tag = "Release_3.12";
    hash = "sha256-tDRBscs2L/3gYgLQvb1+8nNxqkr8v1xBkeDXuOqShX4=";
  };
}

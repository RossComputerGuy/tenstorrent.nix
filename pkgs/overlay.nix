pkgs: prev: with pkgs; {
  tenstorrent = callPackages ./default.nix { };
}

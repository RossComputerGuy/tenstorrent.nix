# tenstorrent.nix

A Nix Flake for using Tenstorrent hardware with Nix/NixOS. Packages are staged
here in nixpkgs form before being upstreamed, so the overlay and module are
drop-in replacements for what nixpkgs provides.

## Overlay

```nix
nixpkgs.overlays = [ tenstorrent.overlays.default ];
```

Provides top-level `tt-umd`, `tt-logger`, `tt-metal`, `tt-smi`, `tt-burnin`,
`tt-topology`, `tt-system-tools`, and `luwen`, extends every Python package set
with `pyluwen`, `tt-flash`, and `tt-tools-common`, and extends kernel package
sets with `tt-kmd`.

## NixOS module

```nix
{
  imports = [ tenstorrent.nixosModules.default ];
  hardware.tenstorrent.enable = true;
}
```

Matches the upstream `hardware.tenstorrent` module, replaces it when both are
present, and applies the overlay automatically.

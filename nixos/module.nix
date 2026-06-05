{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.hardware.tenstorrent;

  tt-kmd = config.boot.kernelPackages.callPackage ../pkgs/tt-kmd { };
in
{
  disabledModules = [ "hardware/tenstorrent.nix" ];

  options.hardware.tenstorrent.enable = mkEnableOption "Tenstorrent driver & utilities";

  config = mkIf cfg.enable {
    nixpkgs.overlays = [ (import ../overlay.nix) ];

    boot = {
      extraModulePackages = [ tt-kmd ];
      kernelModules = [ "tenstorrent" ];
    };

    services.udev.packages = [
      tt-kmd
    ];

    environment.systemPackages = with pkgs; [
      tt-smi
      tt-system-tools
    ];
  };
}

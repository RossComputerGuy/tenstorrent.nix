{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.hardware.tenstorrent;

  tt-kmd = config.boot.kernelPackages.callPackage ../pkgs/tt-kmd { };

  # Resolve meshName to a descriptor shipped in tt-metal. Accept either a stem
  # ("p150_x4") or a full descriptor filename ("..._graph_descriptor.textproto"),
  # since tt-metal's naming is not perfectly uniform.
  meshDescriptorFile =
    if lib.hasSuffix ".textproto" cfg.meshName then
      cfg.meshName
    else
      "${cfg.meshName}_mesh_graph_descriptor.textproto";
  meshDescriptorPath = "${pkgs.tt-metal}/libexec/tt-metalium/tt_metal/fabric/mesh_graph_descriptors/${meshDescriptorFile}";
in
{
  disabledModules = [ "hardware/tenstorrent.nix" ];

  options.hardware.tenstorrent.enable = mkEnableOption "Tenstorrent driver & utilities";

  options.hardware.tenstorrent.meshName = mkOption {
    type = types.nullOr types.str;
    default = null;
    example = "p150_x4";
    description = ''
      Mesh graph descriptor naming this machine's Tenstorrent topology. tt-metal
      does not auto-detect topology: multi-card systems must declare their layout
      so the Metalium backend (and other tt-metal programs, which call
      `open_mesh_device`) can map the fabric instead of aborting under STRICT init.

      Give the stem of a descriptor shipped in tt-metal (for example "p150_x4" for
      a 4x p150 Blackhole QuietBox, "n300", "t3k") or a full descriptor filename.
      When set, `TT_MESH_GRAPH_DESC_PATH` is exported system-wide. Leave null on
      single-card systems, which open a device without needing a descriptor.
    '';
  };

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

    environment.variables = mkIf (cfg.meshName != null) {
      TT_MESH_GRAPH_DESC_PATH = meshDescriptorPath;
    };
  };
}

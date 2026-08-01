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
  vcfg = cfg.vllm;

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
  imports = [
    ./tt-studio.nix
    ./tt-whisper.nix
  ];

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

  options.hardware.tenstorrent.vllm = {
    enable = mkEnableOption "vLLM OpenAI serving on Tenstorrent hardware";

    package = mkOption {
      type = types.package;
      default = pkgs.tt-vllm-server;
      defaultText = lib.literalExpression "pkgs.tt-vllm-server";
      description = "The tt-vllm-server package that provides the tt-vllm-serve wrapper.";
    };

    model = mkOption {
      type = types.str;
      default = "meta-llama/Llama-3.1-8B-Instruct";
      description = ''
        Hugging Face model id (or a local path) to serve. The Tenstorrent stack
        loads bf16 safetensors, not GGUF. Gated repositories need a token, see
        `tokenFile`.
      '';
    };

    meshDevice = mkOption {
      type = types.str;
      default = "P150x4";
      example = "P150";
      description = ''
        Mesh device the vLLM plugin opens. "P150x4" is a four-card Blackhole
        QuietBox; "P150" is a single card. This sets the `MESH_DEVICE` variable.
      '';
    };

    visibleDevices = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "0";
      description = ''
        Restrict the server to specific chips by setting `TT_VISIBLE_DEVICES`
        (and `TT_METAL_VISIBLE_DEVICES`), a comma-separated list of device ids.
        The UMD cluster otherwise opens and locks EVERY chip on the box even when
        `meshDevice` uses a subset, so this is required to leave chips free for
        another service (for example running `services.tt-whisper` on a disjoint
        chip). Null (default) lets the server see all chips. When pinning to a
        single chip, set `meshName` to that chip's descriptor (e.g. "p150") so the
        mesh graph maps onto the visible set.
      '';
    };

    hfModel = mkOption {
      type = types.str;
      default = "meta-llama/Llama-3.1-8B-Instruct";
      description = ''
        Hugging Face model name that tt-metal uses to pick the model family and
        load its own on-device weights. It sets the `HF_MODEL` variable, which the
        tt-metal model library requires. Give the canonical name (for example
        "meta-llama/Llama-3.1-8B-Instruct") even when `model` points at a mirror
        or a local path; the weights are read from the cache or the mirror.
      '';
    };

    servedModelName = mkOption {
      type = types.str;
      default = "meta-llama/Llama-3.1-8B-Instruct";
      description = ''
        Model id the OpenAI API advertises and accepts in requests. Set it to the
        canonical name so clients (such as the tt-studio console) can address the
        model regardless of which mirror `model` loads from.
      '';
    };

    maxNumSeqs = mkOption {
      type = types.ints.positive;
      default = 32;
      description = "Maximum concurrent sequences (the batch size).";
    };

    maxModelLen = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      example = 16384;
      description = ''
        Maximum context length (`--max-model-len`), or null to leave it at the
        model's native length. For dense Llama-class models capping this keeps
        chunked prefill enabled, which measured higher aggregate throughput on the
        mesh.
      '';
    };

    maxNumBatchedTokens = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      example = 16384;
      description = "Token budget per scheduler step (`--max-num-batched-tokens`), or null to omit.";
    };

    enableChunkedPrefill = mkOption {
      type = types.bool;
      default = false;
      description = "Pass `--enable-chunked-prefill`. Not all TT models support it (Qwen3.6 does not).";
    };

    enablePrefixCaching = mkOption {
      type = types.bool;
      default = false;
      description = "Pass `--enable-prefix-caching`.";
    };

    blockSize = mkOption {
      type = types.ints.positive;
      default = 64;
      description = "KV cache block size.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address the OpenAI server binds to.";
    };

    port = mkOption {
      type = types.port;
      default = 8000;
      description = "Port the OpenAI server listens on.";
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/hf-token";
      description = ''
        Path to a file holding a Hugging Face access token, needed for gated
        models. The file is read at start and exported as `HF_TOKEN`; it is never
        copied into the store.
      '';
    };

    additionalConfig = mkOption {
      type = types.attrs;
      default = { };
      example = {
        l1_small_size = 24576;
        trace_region_size = 1073741824;
      };
      description = ''
        Backend config passed to vLLM as `--additional-config` under the `tt` key.
        Some tt-metal models need device parameters here: Qwen3.6, for example,
        needs `l1_small_size` and a large `trace_region_size` for its
        gated-delta-net path on a multi-card mesh. Left empty, the flag is omitted.
      '';
    };

    extraModelsDir = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Directory of vLLM model bundles for the TT plugin (`EXTRA_MODELS_DIR`).
        Each subfolder holds a `vllm_metadata.json` mapping an HF architecture name
        to a `"module:Class"`. Use this to serve tt-metal models the plugin does
        not register on its own, such as the in-tree qwen36 model. Build it in your
        machine config with `pkgs.writeTextDir "qwen36/vllm_metadata.json" ...`.
      '';
    };

    reasoningParser = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "qwen3";
      description = ''
        vLLM reasoning parser (`--reasoning-parser`). For reasoning models such as
        Qwen3.6 this splits the chain-of-thought into a separate response field so
        clients can show only the final answer.
      '';
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "--max-model-len"
        "65536"
      ];
      description = "Extra arguments appended to the `vllm serve` command line.";
    };
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

    systemd.services.tt-vllm = mkIf vcfg.enable {
      description = "Tenstorrent vLLM OpenAI server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        MESH_DEVICE = vcfg.meshDevice;
        # The tt-metal model library requires HF_MODEL to identify the model.
        HF_MODEL = vcfg.hfModel;
        # tt-metal writes its kernel cache and other state under HOME, so give it a
        # writable directory instead of the read-only store.
        HOME = "/var/lib/tt-vllm";
        HF_HOME = "/var/cache/tt-vllm/huggingface";
        # Writable location for the compiled-weight cache.
        TT_CACHE_PATH = "/var/cache/tt-vllm/tt_cache";
      }
      // lib.optionalAttrs (cfg.meshName != null) {
        # systemd services do not read environment.variables, so pass the mesh
        # descriptor path through here as well.
        TT_MESH_GRAPH_DESC_PATH = meshDescriptorPath;
      }
      // lib.optionalAttrs (vcfg.visibleDevices != null) {
        # Pin the server to specific chips so it does not lock the whole box.
        TT_VISIBLE_DEVICES = vcfg.visibleDevices;
        TT_METAL_VISIBLE_DEVICES = vcfg.visibleDevices;
      }
      // lib.optionalAttrs (vcfg.extraModelsDir != null) {
        # Register out-of-tree model bundles with the vLLM TT plugin.
        EXTRA_MODELS_DIR = toString vcfg.extraModelsDir;
      };

      serviceConfig = {
        # Model load plus first-run kernel JIT takes minutes, so allow a long start.
        TimeoutStartSec = "1800";
        Restart = "on-failure";
        RestartSec = "10";

        StateDirectory = "tt-vllm";
        CacheDirectory = "tt-vllm";

        # The Tenstorrent device and its hugepages must be reachable.
        DeviceAllow = [
          "/dev/tenstorrent rw"
          "char-* rw"
        ];
        SupplementaryGroups = [ "render" ];

        LoadCredential = lib.optional (vcfg.tokenFile != null) "hf-token:${vcfg.tokenFile}";

        ExecStart =
          let
            serve = pkgs.writeShellScript "tt-vllm-start" ''
              set -eu
              mkdir -p "$HF_HOME" "$TT_CACHE_PATH"
              ${lib.optionalString (vcfg.tokenFile != null) ''
                export HF_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/hf-token")"
              ''}
              # The 4-card sharding is driven by MESH_DEVICE (set in the service
              # environment), not by vLLM's --tensor-parallel-size: the TT backend
              # rejects vLLM's own distributed execution. tt-metal shards the model
              # across the mesh internally.
              exec ${vcfg.package}/bin/tt-vllm-serve serve ${lib.escapeShellArg vcfg.model} \
                --host ${vcfg.host} \
                --port ${toString vcfg.port} \
                --served-model-name ${lib.escapeShellArg vcfg.servedModelName} \
                --max-num-seqs ${toString vcfg.maxNumSeqs} \
                --block-size ${toString vcfg.blockSize} \
                ${lib.optionalString (vcfg.maxModelLen != null) "--max-model-len ${toString vcfg.maxModelLen}"} \
                ${
                  lib.optionalString (
                    vcfg.maxNumBatchedTokens != null
                  ) "--max-num-batched-tokens ${toString vcfg.maxNumBatchedTokens}"
                } \
                ${lib.optionalString vcfg.enableChunkedPrefill "--enable-chunked-prefill"} \
                ${lib.optionalString vcfg.enablePrefixCaching "--enable-prefix-caching"} \
                ${
                  lib.optionalString (
                    vcfg.reasoningParser != null
                  ) "--reasoning-parser ${lib.escapeShellArg vcfg.reasoningParser}"
                } \
                ${
                  lib.optionalString (vcfg.additionalConfig != { })
                    "--additional-config ${lib.escapeShellArg (builtins.toJSON { tt = vcfg.additionalConfig; })}"
                } \
                ${lib.escapeShellArgs vcfg.extraArgs}
            '';
          in
          "${serve}";
      };
    };
  };
}

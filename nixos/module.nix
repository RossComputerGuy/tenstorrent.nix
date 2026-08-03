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
  # vLLM has no default-system-prompt flag, so to give the model a default system
  # prompt we hand the OpenAI server a custom --chat-template. qwen3ChatmlBase is
  # Qwen3-8B's own ChatML template (its <think> reasoning and tool-call blocks kept
  # verbatim); qwen3InjectPrefix prepends a default system message ONLY when a
  # request carries none, so a client-supplied system prompt still overrides it.
  # The prompt is embedded as a JSON string, a valid Jinja literal (handles quotes
  # and newlines). Assumes a Qwen3 / ChatML model; for others use extraArgs.
  qwen3ChatmlBase = ''
    {%- if tools %}
        {{- '<|im_start|>system\n' }}
        {%- if messages[0].role == 'system' %}
            {{- messages[0].content + '\n\n' }}
        {%- endif %}
        {{- "# Tools\n\nYou may call one or more functions to assist with the user query.\n\nYou are provided with function signatures within <tools></tools> XML tags:\n<tools>" }}
        {%- for tool in tools %}
            {{- "\n" }}
            {{- tool | tojson }}
        {%- endfor %}
        {{- "\n</tools>\n\nFor each function call, return a json object with function name and arguments within <tool_call></tool_call> XML tags:\n<tool_call>\n{\"name\": <function-name>, \"arguments\": <args-json-object>}\n</tool_call><|im_end|>\n" }}
    {%- else %}
        {%- if messages[0].role == 'system' %}
            {{- '<|im_start|>system\n' + messages[0].content + '<|im_end|>\n' }}
        {%- endif %}
    {%- endif %}
    {%- set ns = namespace(multi_step_tool=true, last_query_index=messages|length - 1) %}
    {%- for message in messages[::-1] %}
        {%- set index = (messages|length - 1) - loop.index0 %}
        {%- if ns.multi_step_tool and message.role == "user" and message.content is string and not(message.content.startswith('<tool_response>') and message.content.endswith('</tool_response>')) %}
            {%- set ns.multi_step_tool = false %}
            {%- set ns.last_query_index = index %}
        {%- endif %}
    {%- endfor %}
    {%- for message in messages %}
        {%- if message.content is string %}
            {%- set content = message.content %}
        {%- else %}
            {%- set content = ''' %}
        {%- endif %}
        {%- if (message.role == "user") or (message.role == "system" and not loop.first) %}
            {{- '<|im_start|>' + message.role + '\n' + content + '<|im_end|>' + '\n' }}
        {%- elif message.role == "assistant" %}
            {%- set reasoning_content = ''' %}
            {%- if message.reasoning_content is string %}
                {%- set reasoning_content = message.reasoning_content %}
            {%- else %}
                {%- if '</think>' in content %}
                    {%- set reasoning_content = content.split('</think>')[0].rstrip('\n').split('<think>')[-1].lstrip('\n') %}
                    {%- set content = content.split('</think>')[-1].lstrip('\n') %}
                {%- endif %}
            {%- endif %}
            {%- if loop.index0 > ns.last_query_index %}
                {%- if loop.last or (not loop.last and reasoning_content) %}
                    {{- '<|im_start|>' + message.role + '\n<think>\n' + reasoning_content.strip('\n') + '\n</think>\n\n' + content.lstrip('\n') }}
                {%- else %}
                    {{- '<|im_start|>' + message.role + '\n' + content }}
                {%- endif %}
            {%- else %}
                {{- '<|im_start|>' + message.role + '\n' + content }}
            {%- endif %}
            {%- if message.tool_calls %}
                {%- for tool_call in message.tool_calls %}
                    {%- if (loop.first and content) or (not loop.first) %}
                        {{- '\n' }}
                    {%- endif %}
                    {%- if tool_call.function %}
                        {%- set tool_call = tool_call.function %}
                    {%- endif %}
                    {{- '<tool_call>\n{"name": "' }}
                    {{- tool_call.name }}
                    {{- '", "arguments": ' }}
                    {%- if tool_call.arguments is string %}
                        {{- tool_call.arguments }}
                    {%- else %}
                        {{- tool_call.arguments | tojson }}
                    {%- endif %}
                    {{- '}\n</tool_call>' }}
                {%- endfor %}
            {%- endif %}
            {{- '<|im_end|>\n' }}
        {%- elif message.role == "tool" %}
            {%- if loop.first or (messages[loop.index0 - 1].role != "tool") %}
                {{- '<|im_start|>user' }}
            {%- endif %}
            {{- '\n<tool_response>\n' }}
            {{- content }}
            {{- '\n</tool_response>' }}
            {%- if loop.last or (messages[loop.index0 + 1].role != "tool") %}
                {{- '<|im_end|>\n' }}
            {%- endif %}
        {%- endif %}
    {%- endfor %}
    {%- if add_generation_prompt %}
        {{- '<|im_start|>assistant\n' }}
        {%- if enable_thinking is defined and enable_thinking is false %}
            {{- '<think>\n\n</think>\n\n' }}
        {%- endif %}
    {%- endif %}
  '';
  # `jsonLiteral` must already be JSON-encoded (a valid Jinja double-quoted string).
  qwen3InjectPrefix =
    force: jsonLiteral:
    if force then
      # Force: drop any client-sent system message and make ours the only one, so
      # the default (e.g. a CTF flag) is always present whatever the client sends.
      ''
        {%- set _ns = namespace(kept=[]) %}
        {%- for _m in messages %}{%- if _m.role != 'system' %}{%- set _ns.kept = _ns.kept + [_m] %}{%- endif %}{%- endfor %}
        {%- set messages = [{'role': 'system', 'content': ${jsonLiteral}}] + _ns.kept %}
      ''
    else
      # Default: inject ours only when the client sent no system message.
      ''
        {%- if messages and messages[0].role != 'system' %}
        {%- set messages = [{'role': 'system', 'content': ${jsonLiteral}}] + messages %}
        {%- endif %}
      '';
  # Build-time template for the inline `systemPrompt` option (prompt lands in the
  # store). `systemPromptFile` instead assembles this at start from the base file
  # below, keeping the prompt out of the store; see the serve script.
  qwen3SystemPromptTemplate =
    force: prompt:
    pkgs.writeText "qwen3-chat-template.jinja" (
      qwen3InjectPrefix force (builtins.toJSON prompt) + qwen3ChatmlBase
    );
  # The bare base in the store; the serve script prepends a runtime-built prefix.
  qwen3ChatmlBaseFile = pkgs.writeText "qwen3-chatml-base.jinja" qwen3ChatmlBase;
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

    systemPrompt = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "You are nix.vegas's assistant. Keep answers short.";
      description = ''
        Default system prompt baked into the served model through a custom vLLM
        --chat-template. vLLM has no default-system-prompt flag, so this builds a
        Qwen3 / ChatML template that injects this text as the system message when
        a request sends none (a client-supplied system prompt still overrides it).
        Null (default) keeps the model's own template. Assumes a Qwen3 / ChatML
        model; for other families set the template yourself via extraArgs.
      '';
    };

    systemPromptFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/etc/tt-vllm/system-prompt.txt";
      description = ''
        Path to a file on the machine (out of the store) holding the default
        system prompt. Read at service start and assembled into the chat template
        then, so the text never enters the world-readable store, use this to hide
        a CTF flag in the prompt. Takes precedence over `systemPrompt`. Same
        Qwen3 / ChatML assumption.
      '';
    };

    systemPromptForce = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Force the system prompt: strip any client-sent system message so
        `systemPrompt`/`systemPromptFile` is always the only system message. Off
        by default (a client-supplied system prompt wins). Turn ON for a CTF where
        the prompt (e.g. a hidden flag) must reach the model even though the
        client, such as the tt-studio console, sends its own system prompt.
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
        # Ephemeral tmpfs for a chat template built at start from systemPromptFile
        # (keeps the prompt/flag out of the store); 0700 so only the service reads it.
        RuntimeDirectory = "tt-vllm";
        RuntimeDirectoryMode = "0700";

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
              # Build the --chat-template when a system prompt is set. systemPromptFile
              # wins and is assembled here so its text (which may hold a CTF flag) never
              # enters the store; jq -Rs makes the raw file a JSON string, a valid Jinja
              # literal. The inline systemPrompt uses a template already in the store.
              ${lib.optionalString (vcfg.systemPromptFile != null) ''
                prompt_json="$(${pkgs.jq}/bin/jq -Rs 'rtrimstr("\n")' ${lib.escapeShellArg (toString vcfg.systemPromptFile)})"
                chat_template="$RUNTIME_DIRECTORY/chat-template.jinja"
                {
                  ${
                    if vcfg.systemPromptForce then
                      ''
                        printf '%s\n' "{%- set _ns = namespace(kept=[]) %}"
                        printf '%s\n' "{%- for _m in messages %}{%- if _m.role != 'system' %}{%- set _ns.kept = _ns.kept + [_m] %}{%- endif %}{%- endfor %}"
                        printf '%s\n' "{%- set messages = [{'role': 'system', 'content': $prompt_json}] + _ns.kept %}"
                      ''
                    else
                      ''
                        printf '%s\n' "{%- if messages and messages[0].role != 'system' %}"
                        printf '%s\n' "{%- set messages = [{'role': 'system', 'content': $prompt_json}] + messages %}"
                        printf '%s\n' "{%- endif %}"
                      ''
                  }
                  cat ${qwen3ChatmlBaseFile}
                } > "$chat_template"
              ''}
              ${lib.optionalString (
                vcfg.systemPromptFile == null && vcfg.systemPrompt != null
              ) "chat_template=${qwen3SystemPromptTemplate vcfg.systemPromptForce vcfg.systemPrompt}"}
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
                  lib.optionalString (
                    vcfg.systemPrompt != null || vcfg.systemPromptFile != null
                  ) "--chat-template \"$chat_template\""
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

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

  cfg = config.services.tt-whisper;
in
{
  options.services.tt-whisper = {
    enable = mkEnableOption "the tt-media-server Whisper speech-to-text service (native, on Tenstorrent)";

    package = mkOption {
      type = types.package;
      default = pkgs.tt-media-server;
      defaultText = lib.literalExpression "pkgs.tt-media-server";
      description = "The tt-media-server package to run.";
    };

    model = mkOption {
      type = types.str;
      default = "distil-large-v3";
      description = ''
        Whisper model to serve. The short tt-media-server ModelNames value, e.g.
        `distil-large-v3` or `whisper-large-v3` (NOT the full HF repo path). Weights
        are pulled from the Hugging Face cache (downloaded on first run unless
        pre-staged).
      '';
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address the server binds to.";
    };

    port = mkOption {
      type = types.port;
      default = 8030;
      description = "Port the speech-to-text server listens on.";
    };

    device = mkOption {
      type = types.str;
      default = "p150";
      description = "tt-media-server device type (e.g. `p150` for a single Blackhole card).";
    };

    deviceIds = mkOption {
      type = types.str;
      default = "(0)";
      example = "(1)";
      description = ''
        tt-media-server DEVICE_IDS selecting which chip(s) to use, in its own
        parenthesised form. tt-media-server assigns devices by this setting, NOT by
        `TT_VISIBLE_DEVICES`. Use a chip disjoint from any LLM service on the box.
      '';
    };

    apiKey = mkOption {
      type = types.str;
      default = "sk-none";
      description = ''
        Bearer API key required on requests (`Authorization: Bearer <apiKey>`). Set
        the tt-studio `cloudSpeechAuthToken` to the same value.
      '';
    };

    allowPreprocessing = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the whisperx/pyannote/silero VAD + diarization path. Off by default
        (Tier-1): that path lives in a separate CPU venv this package does not ship,
        so leave it off unless that venv is provided via AUDIO_VENV_PYTHON.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the server port in the firewall. Off by default; keep it host-local.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.tt-whisper = {
      description = "tt-media-server Whisper speech-to-text (Tenstorrent)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      environment = {
        # StateDirectory holds the writable tt-metal-home symlink-farm, the
        # writable app copy, and (via HOME) the tt-metal op-kernel cache. The
        # launcher populates the farm/run copy here on first start.
        HOME = "/var/lib/tt-whisper";
        TT_MEDIA_STATE_DIR = "/var/lib/tt-whisper/state";
        HF_HOME = "/var/cache/tt-whisper/huggingface";
        TT_MEDIA_HOST = cfg.host;
        TT_MEDIA_PORT = toString cfg.port;
        API_KEY = cfg.apiKey;
        MODEL_RUNNER = "tt-whisper";
        MODEL = cfg.model;
        DEVICE = cfg.device;
        DEVICE_IDS = cfg.deviceIds;
        IS_GALAXY = "false";
        ALLOW_AUDIO_PREPROCESSING = lib.boolToString cfg.allowPreprocessing;
        DOWNLOAD_WEIGHTS_FROM_SERVICE = "false";
      };
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/tt-media-serve";
        StateDirectory = "tt-whisper";
        CacheDirectory = "tt-whisper";
        Restart = "on-failure";
        RestartSec = "10";
        # First start compiles dispatch kernels and captures traces (~1 min) and
        # may download the model, so give startup generous headroom.
        TimeoutStartSec = "1200";
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
  };
}

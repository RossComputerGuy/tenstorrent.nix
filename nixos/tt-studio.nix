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

  cfg = config.services.tt-studio;

  chromaHost = "127.0.0.1";
  backendHost = "127.0.0.1";

  # Common environment for the Django backend. It never spawns Docker; the chat
  # streams to an external OpenAI-compatible server via CLOUD_CHAT_UI_URL.
  backendEnv = {
    DJANGO_SETTINGS_MODULE = "api.settings";
    BACKEND_API_HOSTNAME = backendHost;
    TT_STUDIO_ROOT = "/var/lib/tt-studio";
    HOST_PERSISTENT_STORAGE_VOLUME = "/var/lib/tt-studio/host";
    INTERNAL_PERSISTENT_STORAGE_VOLUME = "/var/lib/tt-studio/internal";
    CHROMA_DB_HOST = chromaHost;
    CHROMA_DB_PORT = toString cfg.chromaPort;
    CLOUD_CHAT_UI_URL = cfg.cloudChatUrl;
  };
in
{
  options.services.tt-studio = {
    enable = mkEnableOption "the tt-studio web console (native, no Docker)";

    frontend = mkOption {
      type = types.package;
      default = pkgs.tt-studio-frontend;
      defaultText = lib.literalExpression "pkgs.tt-studio-frontend";
      description = "The built tt-studio frontend package (serves its dist/ over nginx).";
    };

    backend = mkOption {
      type = types.package;
      default = pkgs.tt-studio-backend;
      defaultText = lib.literalExpression "pkgs.tt-studio-backend";
      description = "The tt-studio Django backend package.";
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port nginx serves the console on.";
    };

    backendPort = mkOption {
      type = types.port;
      default = 8001;
      description = "Port the Django backend listens on (internal).";
    };

    chromaPort = mkOption {
      type = types.port;
      default = 8111;
      description = "Port the Chroma vector database listens on (internal).";
    };

    cloudChatUrl = mkOption {
      type = types.str;
      default = "http://127.0.0.1:8000/v1/chat/completions";
      description = ''
        Full OpenAI-compatible chat endpoint the console streams to. Point this at
        the tt-vllm server. It must include the `/v1/chat/completions` path: the
        backend forwards the request body to this URL unchanged.
      '';
    };

    cloudChatAuthToken = mkOption {
      type = types.str;
      default = "sk-none";
      description = ''
        Bearer token the backend sends to the chat endpoint. vLLM ignores it when
        no API key is set, but it must be non-empty, an empty token produces an
        illegal `Authorization: Bearer ` header that httpx rejects.
      '';
    };

    cloudSpeechUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "http://127.0.0.1:8030/v1/audio/transcriptions";
      description = ''
        Full speech-to-text endpoint the console posts mic audio to (the console's
        cloud speech path). Point this at a tt-media-server Whisper instance's
        `/v1/audio/transcriptions`. The backend forwards a multipart `file` and
        expects JSON with a `text` field. Null (default) leaves speech-to-text
        unconfigured.
      '';
    };

    cloudSpeechAuthToken = mkOption {
      type = types.str;
      default = "sk-none";
      description = ''
        Bearer token the backend sends to the speech endpoint. Must match the
        tt-media-server `API_KEY` (or any value when the server runs with NO_AUTH).
        Must be non-empty for the same `Authorization: Bearer ` reason as the chat
        token.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the console port in the firewall. Off by default; use an SSH tunnel.";
    };
  };

  config = mkIf cfg.enable {
    # Chroma vector database (RAG/collections features; the backend connects to it
    # at boot).
    systemd.services.tt-studio-chroma = {
      description = "tt-studio Chroma vector database";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = ''
          ${cfg.backend.python}/bin/chroma run \
            --host ${chromaHost} --port ${toString cfg.chromaPort} \
            --path /var/lib/tt-studio-chroma
        '';
        StateDirectory = "tt-studio-chroma";
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = "5";
      };
    };

    # Django backend: migrate on start, then serve ASGI via uvicorn.
    systemd.services.tt-studio-backend = {
      description = "tt-studio Django backend";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "tt-studio-chroma.service"
      ];
      wants = [ "tt-studio-chroma.service" ];
      environment =
        backendEnv
        // {
          CLOUD_CHAT_UI_AUTH_TOKEN = cfg.cloudChatAuthToken;
        }
        // lib.optionalAttrs (cfg.cloudSpeechUrl != null) {
          CLOUD_SPEECH_RECOGNITION_URL = cfg.cloudSpeechUrl;
          CLOUD_SPEECH_RECOGNITION_AUTH_TOKEN = cfg.cloudSpeechAuthToken;
        };
      serviceConfig = {
        StateDirectory = "tt-studio";
        Restart = "on-failure";
        RestartSec = "5";
        # Create the storage volumes the settings expect, run migrations, then serve.
        ExecStartPre = pkgs.writeShellScript "tt-studio-backend-pre" ''
          set -eu
          mkdir -p "$HOST_PERSISTENT_STORAGE_VOLUME" \
                   "$INTERNAL_PERSISTENT_STORAGE_VOLUME/backend_volume"
          ${cfg.backend}/bin/tt-studio-manage migrate --noinput
        '';
        ExecStart = ''
          ${cfg.backend}/bin/tt-studio-backend \
            --host ${backendHost} --port ${toString cfg.backendPort} \
            --workers 2 --timeout-keep-alive 1200
        '';
      };
    };

    # nginx serves the frontend dist/ and proxies the API paths to the backend.
    # Composes with any other nginx virtual hosts on the machine.
    services.nginx = {
      enable = true;
      virtualHosts."tt-studio" = {
        listen = [
          {
            addr = "0.0.0.0";
            inherit (cfg) port;
          }
        ];
        root = "${cfg.frontend}/dist";
        locations =
          let
            api = path: {
              proxyPass = "http://${backendHost}:${toString cfg.backendPort}${path}";
            };
            stream = path: {
              proxyPass = "http://${backendHost}:${toString cfg.backendPort}${path}";
              extraConfig = ''
                proxy_buffering off;
                proxy_read_timeout 1200s;
              '';
            };
          in
          {
            "/models-api/" = stream "/models/";
            "/docker-api/" = stream "/docker/";
            "/board-api/" = api "/board/";
            "/logs-api/" = api "/logs/";
            "/collections-api/" = api "/collections/";
            "/vector-db-api/" = api "/collections/";
            "/settings-api/" = api "/settings/";
            "/up/" = api "/up/";
            "/" = {
              tryFiles = "$uri $uri/ /index.html";
            };
          };
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
  };
}

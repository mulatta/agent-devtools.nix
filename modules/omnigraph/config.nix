{
  config,
  lib,
  ...
}:
let
  cfg = config.services.omnigraph;

  authEnvVars = [
    "OMNIGRAPH_SERVER_BEARER_TOKEN"
    "OMNIGRAPH_SERVER_BEARER_TOKENS_JSON"
    "OMNIGRAPH_SERVER_BEARER_TOKENS_FILE"
    "OMNIGRAPH_SERVER_BEARER_TOKENS_AWS_SECRET"
  ];

  hasAuthEnv = lib.any (name: lib.hasAttr name cfg.environment) authEnvVars;

  bind = "${cfg.listenAddress}:${toString cfg.port}";

  localClusterPaths = lib.optional (lib.hasPrefix "/" cfg.cluster) cfg.cluster;

  readWritePaths = [ cfg.dataDir ] ++ localClusterPaths ++ cfg.writablePaths;

  commandArgs = [
    "--cluster"
    cfg.cluster
    "--bind"
    bind
  ]
  ++ lib.optional cfg.unauthenticated "--unauthenticated"
  ++ lib.optional cfg.requireAllGraphs "--require-all-graphs"
  ++ cfg.extraArgs;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.cluster != "";
        message = "services.omnigraph.cluster must not be empty";
      }
    ];

    warnings =
      lib.optional
        (!cfg.unauthenticated && cfg.bearerTokensFile == null && cfg.environmentFiles == [ ] && !hasAuthEnv)
        "services.omnigraph: omnigraph-server refuses startup without a bearer token source unless unauthenticated is enabled";

    users.groups = lib.mkIf cfg.createUser {
      ${cfg.group} = { };
    };

    users.users = lib.mkIf cfg.createUser {
      ${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group;
        home = cfg.dataDir;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.omnigraph-server = {
      description = "Omnigraph HTTP server";
      documentation = [ "https://github.com/ModernRelay/omnigraph" ];
      wantedBy = lib.optional cfg.autoStart "multi-user.target";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      inherit (cfg) environment;
      path = [ cfg.package ];

      script = ''
        set -euo pipefail
        ${lib.optionalString (cfg.bearerTokensFile != null) ''
          export OMNIGRAPH_SERVER_BEARER_TOKENS_FILE="$CREDENTIALS_DIRECTORY/bearer-tokens"
        ''}
        export HOME=${lib.escapeShellArg cfg.dataDir}
        exec ${lib.getExe cfg.package} ${lib.escapeShellArgs commandArgs}
      '';

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "5s";
        EnvironmentFile = cfg.environmentFiles;
        LoadCredential = lib.optional (
          cfg.bearerTokensFile != null
        ) "bearer-tokens:${cfg.bearerTokensFile}";
        StateDirectory = "omnigraph";
        WorkingDirectory = cfg.dataDir;
        UMask = "0077";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = readWritePaths;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}

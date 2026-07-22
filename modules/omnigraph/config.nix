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
  ];

  hasNonEmptyEnv = name: lib.trim (cfg.environment.${name} or "") != "";

  usesAwsSecretManager = hasNonEmptyEnv "OMNIGRAPH_SERVER_BEARER_TOKENS_AWS_SECRET";

  hasAuthEnv = lib.any hasNonEmptyEnv authEnvVars;

  formattedListenAddress =
    if lib.hasPrefix "[" cfg.listenAddress && lib.hasSuffix "]" cfg.listenAddress then
      cfg.listenAddress
    else if lib.hasInfix ":" cfg.listenAddress then
      "[${cfg.listenAddress}]"
    else
      cfg.listenAddress;

  bind = "${formattedListenAddress}:${toString cfg.port}";

  clusterIsAbsolutePath = lib.hasPrefix "/" cfg.cluster;

  localClusterPaths = lib.optional clusterIsAbsolutePath cfg.cluster;

  readWritePaths = [ cfg.dataDir ] ++ localClusterPaths ++ cfg.writablePaths;

  isProtectedHomePath =
    path:
    lib.any (root: path == root || lib.hasPrefix "${root}/" path) [
      "/home"
      "/root"
      "/run/user"
    ];

  managedArgs = [
    "--cluster"
    "--bind"
    "--unauthenticated"
    "--require-all-graphs"
  ];

  isManagedArg = arg: lib.any (flag: arg == flag || lib.hasPrefix "${flag}=" arg) managedArgs;

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
        assertion = cfg.dataDir != "/";
        message = "services.omnigraph.dataDir must not be the filesystem root";
      }
      {
        assertion = !lib.any isProtectedHomePath readWritePaths;
        message = "services.omnigraph writable paths must not be hidden by ProtectHome";
      }
      {
        assertion = !lib.any isManagedArg cfg.extraArgs;
        message = "services.omnigraph.extraArgs must not repeat arguments managed by typed options";
      }
      {
        assertion =
          cfg.bearerTokensFile == null || !lib.hasAttr "OMNIGRAPH_SERVER_BEARER_TOKENS_FILE" cfg.environment;
        message = "services.omnigraph.bearerTokensFile conflicts with environment.OMNIGRAPH_SERVER_BEARER_TOKENS_FILE";
      }
    ];

    warnings =
      lib.optional (!cfg.unauthenticated && cfg.bearerTokensFile == null && !hasAuthEnv) (
        if cfg.environmentFiles == [ ] then
          "services.omnigraph: no bearer token source configured; omnigraph-server will refuse startup"
        else
          "services.omnigraph: auth supplied through environmentFiles is checked only when the server starts"
      )
      ++ lib.optional usesAwsSecretManager "services.omnigraph: default omnigraph-server package lacks optional AWS Secrets Manager bearer-token support; use bearerTokensFile or environmentFiles";

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

    systemd.tmpfiles.settings."10-omnigraph".${cfg.dataDir}.d = {
      inherit (cfg) user;
      inherit (cfg) group;
      mode = "0750";
    };

    systemd.services.omnigraph-server = {
      description = "Omnigraph HTTP server";
      documentation = [ "https://github.com/ModernRelay/omnigraph" ];
      wantedBy = lib.optional cfg.autoStart "multi-user.target";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      inherit (cfg) environment;

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

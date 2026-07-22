{
  lib,
  nixosSystem,
  pkgs,
  self,
  system,
}:
let
  testPackage = pkgs.writeShellScriptBin "omnigraph-server" ''
    echo test omnigraph-server "$@"
  '';

  baseInternalConfig = {
    enable = true;
    package = testPackage;
    cluster = "s3://omnigraph/clusters/main";
    unauthenticated = true;
  };

  mkConfig =
    {
      module ? ./.,
      omnigraph,
    }:
    nixosSystem {
      inherit system;
      modules = [
        module
        {
          nixpkgs.pkgs = pkgs;
          system.stateVersion = "26.05";
          services.omnigraph = omnigraph;
        }
      ];
    };

  fixtures = {
    local = mkConfig {
      omnigraph = baseInternalConfig // {
        cluster = "/srv/omnigraph/company-brain";
        listenAddress = "::1";
        bearerTokensFile = "/run/secrets/omnigraph-bearer-tokens.json";
        environmentFiles = [
          "-/run/secrets/optional.env"
          "/run/secrets/required.env"
        ];
        unauthenticated = false;
        requireAllGraphs = true;
        extraArgs = [ "--future-option=value" ];
        autoStart = false;
        openFirewall = true;
        user = "omnigraph-test";
        group = "omnigraph-test";
        dataDir = "/srv/omnigraph-state";
      };
    };

    s3 = mkConfig {
      omnigraph = baseInternalConfig;
    };

    invalidRelativePath = mkConfig {
      omnigraph = baseInternalConfig // {
        cluster = "relative/cluster";
      };
    };

    invalidRootDataDir = mkConfig {
      omnigraph = baseInternalConfig // {
        dataDir = "/";
      };
    };

    invalidProtectedHomePath = mkConfig {
      omnigraph = baseInternalConfig // {
        dataDir = "/home/omnigraph";
      };
    };

    invalidManagedArg = mkConfig {
      omnigraph = baseInternalConfig // {
        extraArgs = [ "--bind=0.0.0.0:9000" ];
      };
    };

    invalidBearerConflict = mkConfig {
      omnigraph = baseInternalConfig // {
        bearerTokensFile = "/run/secrets/omnigraph-bearer-tokens.json";
        environment.OMNIGRAPH_SERVER_BEARER_TOKENS_FILE = "/run/secrets/other.json";
      };
    };

    missingAuth = mkConfig {
      omnigraph = baseInternalConfig // {
        unauthenticated = false;
      };
    };

    blankAuth = mkConfig {
      omnigraph = baseInternalConfig // {
        unauthenticated = false;
        environment.OMNIGRAPH_SERVER_BEARER_TOKEN = "   ";
      };
    };

    environmentFileAuth = mkConfig {
      omnigraph = baseInternalConfig // {
        unauthenticated = false;
        environmentFiles = [ "/run/secrets/omnigraph.env" ];
      };
    };

    awsSecret = mkConfig {
      omnigraph = baseInternalConfig // {
        unauthenticated = false;
        environment.OMNIGRAPH_SERVER_BEARER_TOKENS_AWS_SECRET = "omnigraph/tokens";
      };
    };

    publicModule = mkConfig {
      module = self.nixosModules.omnigraph;
      omnigraph = {
        enable = true;
        cluster = "s3://omnigraph/clusters/main";
        unauthenticated = true;
      };
    };
  };

  serviceOf = nixosConfig: nixosConfig.config.systemd.services.omnigraph-server;

  hasFailedAssertion =
    message: nixosConfig:
    lib.any (
      assertion: !assertion.assertion && assertion.message == message
    ) nixosConfig.config.assertions;

  hasWarning = fragment: nixosConfig: lib.any (lib.hasInfix fragment) nixosConfig.config.warnings;

  service = serviceOf fixtures.local;
  publicService = serviceOf fixtures.publicModule;

  checks = {
    clusterArgument = lib.hasInfix "--cluster /srv/omnigraph/company-brain" service.script;
    ipv6Bind = lib.hasInfix "--bind '[::1]:8080'" service.script;
    requireAllGraphs = lib.hasInfix "--require-all-graphs" service.script;
    extraArgs = lib.hasInfix "--future-option=value" service.script;
    bearerCredentialEnvironment = lib.hasInfix ''OMNIGRAPH_SERVER_BEARER_TOKENS_FILE="$CREDENTIALS_DIRECTORY/bearer-tokens"'' service.script;
    homeEnvironment = lib.hasInfix "export HOME=/srv/omnigraph-state" service.script;
    readWritePaths =
      service.serviceConfig.ReadWritePaths == [
        "/srv/omnigraph-state"
        "/srv/omnigraph/company-brain"
      ];
    s3ReadWritePaths =
      (serviceOf fixtures.s3).serviceConfig.ReadWritePaths == [
        "/var/lib/omnigraph"
      ];
    firewall = fixtures.local.config.networking.firewall.allowedTCPPorts == [ 8080 ];
    environmentFiles =
      service.serviceConfig.EnvironmentFile == [
        "-/run/secrets/optional.env"
        "/run/secrets/required.env"
      ];
    serviceIdentity =
      service.serviceConfig.User == "omnigraph-test" && service.serviceConfig.Group == "omnigraph-test";
    userCreation =
      fixtures.local.config.users.users.omnigraph-test.group == "omnigraph-test"
      && fixtures.local.config.users.users.omnigraph-test.isSystemUser;
    groupCreation = fixtures.local.config.users.groups ? omnigraph-test;
    workingDirectory = service.serviceConfig.WorkingDirectory == "/srv/omnigraph-state";
    tmpfiles =
      let
        rule = fixtures.local.config.systemd.tmpfiles.settings."10-omnigraph"."/srv/omnigraph-state".d;
      in
      rule.user == "omnigraph-test" && rule.group == "omnigraph-test" && rule.mode == "0750";
    bearerCredential =
      service.serviceConfig.LoadCredential == [
        "bearer-tokens:/run/secrets/omnigraph-bearer-tokens.json"
      ];
    autoStartDisabled = service.wantedBy == [ ];
    autoStartEnabled = (serviceOf fixtures.s3).wantedBy == [ "multi-user.target" ];
    noHardcodedStateDirectory = !(service.serviceConfig ? StateDirectory);
    relativePathRejected = !(builtins.tryEval (serviceOf fixtures.invalidRelativePath).script).success;
    rootDataDirRejected = hasFailedAssertion "services.omnigraph.dataDir must not be the filesystem root" fixtures.invalidRootDataDir;
    protectedHomePathRejected = hasFailedAssertion "services.omnigraph writable paths must not be hidden by ProtectHome" fixtures.invalidProtectedHomePath;
    managedArgRejected = hasFailedAssertion "services.omnigraph.extraArgs must not repeat arguments managed by typed options" fixtures.invalidManagedArg;
    bearerConflictRejected = hasFailedAssertion "services.omnigraph.bearerTokensFile conflicts with environment.OMNIGRAPH_SERVER_BEARER_TOKENS_FILE" fixtures.invalidBearerConflict;
    missingAuthWarning = hasWarning "no bearer token source configured" fixtures.missingAuth;
    blankAuthWarning = hasWarning "no bearer token source configured" fixtures.blankAuth;
    environmentFileAuthWarning = hasWarning "auth supplied through environmentFiles is checked only when the server starts" fixtures.environmentFileAuth;
    unauthenticatedSuppressesAuthWarning = !hasWarning "bearer token source" fixtures.s3;
    bearerFileSuppressesAuthWarning = !hasWarning "bearer token source" fixtures.local;
    awsSecretWarning = hasWarning "lacks optional AWS Secrets Manager bearer-token support" fixtures.awsSecret;
    publicPackageInjection =
      fixtures.publicModule.config.services.omnigraph.package.pname == "omnigraph-server";
    publicServiceEnabled = lib.hasInfix "/bin/omnigraph-server" publicService.script;
  };

  failedChecks = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
assert lib.assertMsg (
  failedChecks == [ ]
) "Omnigraph module checks failed: ${lib.concatStringsSep ", " failedChecks}";
pkgs.runCommand "omnigraph-module-check" { } ''
  touch "$out"
''

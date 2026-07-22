{
  self,
  lib,
  pkgs,
  ...
}:
{
  options.services.omnigraph = {
    enable = lib.mkEnableOption "Omnigraph HTTP server";

    package =
      lib.mkPackageOption self.packages.${pkgs.stdenv.hostPlatform.system} "omnigraph-server"
        { };

    cluster = lib.mkOption {
      type = lib.types.str;
      example = "s3://omnigraph/clusters/company-brain";
      description = ''
        Cluster boot source passed to omnigraph-server --cluster. Use a local
        cluster directory or an object-storage root URI.
      '';
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address omnigraph-server binds to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "TCP port omnigraph-server binds to.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the Omnigraph TCP port in the firewall.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Start omnigraph-server during boot. Disable while bootstrapping a
        remote cluster root that has not received its first applied revision.
      '';
    };

    unauthenticated = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Start in unauthenticated mode. Use only for local development; shared
        deployments should configure a bearer token source instead.
      '';
    };

    requireAllGraphs = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Abort startup when any graph in the applied cluster revision cannot be
        served, instead of quarantining failed graphs.
      '';
    };

    bearerTokensFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/omnigraph-bearer-tokens.json";
      description = ''
        Runtime path to a JSON token map of actor IDs to bearer tokens. The file
        is passed through a systemd credential and exposed to the server via
        OMNIGRAPH_SERVER_BEARER_TOKENS_FILE.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Extra environment variables for omnigraph-server, such as AWS_* object
        storage settings or embedding-provider secrets.
      '';
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/run/secrets/omnigraph.env" ];
      description = ''
        Environment files loaded by systemd. Use this for S3 credentials,
        embedding provider keys, or bearer token variables managed outside Nix.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional command-line arguments passed to omnigraph-server.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "omnigraph";
      description = "User account that runs omnigraph-server.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "omnigraph";
      description = "Group account that runs omnigraph-server.";
    };

    createUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create the configured system user and group.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/omnigraph";
      description = "State directory used as HOME and writable local storage.";
    };

    writablePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/srv/omnigraph" ];
      description = ''
        Extra local paths omnigraph-server may write. Add local cluster roots
        outside dataDir here when ProtectSystem=strict is enabled.
      '';
    };
  };
}

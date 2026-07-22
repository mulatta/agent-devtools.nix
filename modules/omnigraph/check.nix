{
  inputs,
  pkgs,
  self,
  system,
}:
let
  testPackage = pkgs.writeShellScriptBin "omnigraph-server" ''
    echo test omnigraph-server "$@"
  '';

  moduleConfig = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit self; };
    modules = [
      ./.
      {
        nixpkgs.pkgs = pkgs;
        services.omnigraph = {
          enable = true;
          package = testPackage;
          cluster = "/srv/omnigraph/company-brain";
          unauthenticated = true;
          openFirewall = true;
        };
      }
    ];
  };
in
pkgs.runCommand "omnigraph-module-check"
  {
    script = moduleConfig.config.systemd.services.omnigraph-server.script;
    readWritePaths = builtins.toJSON moduleConfig.config.systemd.services.omnigraph-server.serviceConfig.ReadWritePaths;
    firewallPorts = builtins.toJSON moduleConfig.config.networking.firewall.allowedTCPPorts;
  }
  ''
    set -euo pipefail
    grep -F -- "--cluster /srv/omnigraph/company-brain" <<< "$script"
    grep -F -- "--bind 127.0.0.1:8080" <<< "$script"
    grep -F -- "--unauthenticated" <<< "$script"
    test "$readWritePaths" = '["/var/lib/omnigraph","/srv/omnigraph/company-brain"]'
    test "$firewallPorts" = '[8080]'
    touch "$out"
  ''

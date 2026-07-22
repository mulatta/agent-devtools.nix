{
  pkgs,
  self,
  system,
}:
let
  fixture = ./fixtures/minimal;
  omnigraphCli = self.packages.${system}.omnigraph-cli;
  omnigraphServer = self.packages.${system}.omnigraph-server;
in
pkgs.testers.runNixOSTest {
  name = "omnigraph";

  nodes.machine = {
    imports = [ self.nixosModules.omnigraph ];

    services.omnigraph = {
      enable = true;
      cluster = "/var/lib/omnigraph/cluster";
      bearerTokensFile = "/run/secrets/omnigraph-bearer-tokens.json";
      autoStart = false;
    };

    environment.systemPackages = [
      omnigraphCli
      pkgs.curl
      pkgs.jq
    ];

    virtualisation = {
      cores = 2;
      diskSize = 4096;
      memorySize = 4096;
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    machine.succeed("install -d -o omnigraph -g omnigraph /var/lib/omnigraph/cluster")
    machine.succeed("cp ${fixture}/cluster.yaml ${fixture}/research.pg /var/lib/omnigraph/cluster/")
    machine.succeed("chown -R omnigraph:omnigraph /var/lib/omnigraph/cluster")

    machine.succeed("install -d -m 0700 /run/secrets")
    machine.succeed("printf '%s\\n' '{\"act-test\":\"test-token\"}' > /run/secrets/omnigraph-bearer-tokens.json")
    machine.succeed("chmod 0400 /run/secrets/omnigraph-bearer-tokens.json")

    machine.succeed("omnigraph cluster import --config /var/lib/omnigraph/cluster")
    machine.succeed("omnigraph cluster apply --config /var/lib/omnigraph/cluster")
    machine.succeed("chown -R omnigraph:omnigraph /var/lib/omnigraph/cluster")

    machine.succeed("systemctl start omnigraph-server.service")
    machine.wait_for_unit("omnigraph-server.service")
    machine.wait_for_open_port(8080)

    machine.succeed("curl -fsS http://127.0.0.1:8080/healthz | jq -e '.status == \"ok\" and .version == \"${omnigraphServer.version}\"'")
    machine.succeed("test \"$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/graphs/research/branches)\" = 401")
    machine.succeed("curl -fsS -H 'Authorization: Bearer test-token' http://127.0.0.1:8080/graphs/research/branches | jq -e '.branches | type == \"array\"'")

    machine.succeed("printf '%s\\n' '{\"act-test\":\"rotated-token\"}' > /run/secrets/omnigraph-bearer-tokens.json")
    machine.succeed("systemctl restart omnigraph-server.service")
    machine.wait_for_unit("omnigraph-server.service")
    machine.wait_for_open_port(8080)

    machine.succeed("test \"$(curl -sS -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer test-token' http://127.0.0.1:8080/graphs/research/branches)\" = 401")
    machine.succeed("curl -fsS -H 'Authorization: Bearer rotated-token' http://127.0.0.1:8080/graphs/research/branches | jq -e '.branches | type == \"array\"'")
  '';
}

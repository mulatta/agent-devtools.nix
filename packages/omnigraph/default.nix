{
  perSystem,
  pkgs,
  ...
}:

let
  inherit (perSystem.self) omnigraph-cli omnigraph-server;
  inherit (pkgs) lib;
in
pkgs.symlinkJoin {
  name = "omnigraph-${omnigraph-cli.version}";
  paths = [
    omnigraph-cli
    omnigraph-server
  ];
  passthru = {
    cli = omnigraph-cli;
    server = omnigraph-server;
    inherit (omnigraph-cli) src version;
  };
  meta = {
    description = "Lakehouse graph database for context assembly and multi-agent coordination";
    homepage = "https://github.com/ModernRelay/omnigraph";
    changelog = "https://github.com/ModernRelay/omnigraph/releases/tag/v${omnigraph-cli.version}";
    license = lib.licenses.mit;
    mainProgram = "omnigraph";
    inherit (omnigraph-cli.meta) maintainers;
    platforms = lib.platforms.linux;
  };
}

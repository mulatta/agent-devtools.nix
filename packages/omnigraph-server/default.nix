{ craneLib, pkgs, ... }:

let
  omnigraphCommon = pkgs.callPackage ../omnigraph/common.nix { inherit craneLib; };
in
omnigraphCommon.mkPackage {
  pname = "omnigraph-server";
  cargoExtraArgs = "-p omnigraph-server";
  installCheckCommand = ''
    "$out/bin/omnigraph-server" --help >/dev/null
  '';
  description = "HTTP server for the Omnigraph graph database";
  mainProgram = "omnigraph-server";
}

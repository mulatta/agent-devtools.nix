{ craneLib, pkgs, ... }:

let
  omnigraphCommon = pkgs.callPackage ../omnigraph/common.nix { inherit craneLib; };
in
omnigraphCommon.mkPackage {
  pname = "omnigraph-cli";
  cargoExtraArgs = "-p omnigraph-cli";
  useVersionCheckHook = true;
  description = "Command-line interface for the Omnigraph graph database";
  mainProgram = "omnigraph";
}

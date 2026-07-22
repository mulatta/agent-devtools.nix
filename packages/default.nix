{ pkgs, craneLib }:

let
  inherit (pkgs) lib;
  omnigraphPackages = pkgs.callPackage ./omnigraph { inherit craneLib; };
in
{
  omnigraph-cli = omnigraphPackages.cli;
  omnigraph-server = omnigraphPackages.server;
}
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  omnigraph = omnigraphPackages.combined;
}

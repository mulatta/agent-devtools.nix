{
  description = "Nix packages and modules for RAG integration";

  inputs = {
    # keep-sorted start
    crane.url = "github:ipetkov/crane";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    # keep-sorted end
  };

  outputs =
    {
      self,
      crane,
      nixpkgs,
      treefmt-nix,
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachSystem = lib.genAttrs systems;

      callWith = args: fn: fn (builtins.intersectAttrs (builtins.functionArgs fn) args);

      packageNames = builtins.attrNames (
        lib.filterAttrs (
          name: type: type == "directory" && builtins.pathExists (./packages + "/${name}/default.nix")
        ) (builtins.readDir ./packages)
      );

      pkgsFor = eachSystem (system: nixpkgs.legacyPackages.${system});

      mkPackagesFor =
        pkgs:
        let
          perSystem = {
            self = packages;
          };
          packages = lib.genAttrs packageNames (
            name:
            callWith {
              inherit perSystem pkgs;
              craneLib = crane.mkLib pkgs;
              system = pkgs.stdenv.hostPlatform.system;
            } (import (./packages + "/${name}"))
          );
        in
        packages;

      allPackages = eachSystem (system: mkPackagesFor pkgsFor.${system});

      available =
        system: pkg:
        lib.meta.availableOn pkgsFor.${system}.stdenv.hostPlatform pkg && !(pkg.meta.broken or false);

      packages = eachSystem (system: lib.filterAttrs (_name: available system) allPackages.${system});

      treefmtEval = eachSystem (
        system:
        treefmt-nix.lib.evalModule pkgsFor.${system} {
          projectRootFile = "flake.nix";
          programs = {
            deadnix.enable = true;
            keep-sorted.enable = true;
            nixfmt.enable = true;
            statix.enable = true;
          };
        }
      );
    in
    {
      inherit packages;

      checks = eachSystem (
        system:
        {
          formatting = treefmtEval.${system}.config.build.check self;
        }
        // lib.mapAttrs' (name: lib.nameValuePair "package-${name}") packages.${system}
      );

      formatter = eachSystem (system: treefmtEval.${system}.config.build.wrapper);
    };
}

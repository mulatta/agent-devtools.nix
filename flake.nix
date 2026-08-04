{
  description = "Nix packages and modules for agent development tools";

  inputs = {
    # keep-sorted start
    crane.url = "github:ipetkov/crane";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    # keep-sorted end
  };

  outputs =
    inputs@{
      self,
      crane,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachSystem = lib.genAttrs systems;

      flake = self // {
        inherit inputs;
      };

      callWith = args: fn: fn (builtins.intersectAttrs (builtins.functionArgs fn) args);

      packageNames = builtins.attrNames (
        lib.filterAttrs (
          name: type: type == "directory" && builtins.pathExists (./packages + "/${name}/default.nix")
        ) (builtins.readDir ./packages)
      );

      moduleNames = builtins.attrNames (
        lib.filterAttrs (_name: type: type == "directory") (builtins.readDir ./modules)
      );

      moduleNamesWith =
        file: lib.filter (name: builtins.pathExists (./modules + "/${name}/${file}")) moduleNames;

      prefixAttrs = prefix: lib.mapAttrs' (name: lib.nameValuePair "${prefix}-${name}");

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
              inherit
                flake
                inputs
                perSystem
                pkgs
                ;
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

      devShells = eachSystem (system: {
        default = callWith {
          pkgs = pkgsFor.${system};
          perSystem = {
            self = allPackages.${system};
          };
        } (import ./devshell.nix);
      });
    in
    {
      inherit devShells packages;

      nixosModules = import ./modules { inherit self; };

      checks = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
          args = {
            inherit
              lib
              pkgs
              self
              system
              ;
            nixosSystem = nixpkgs.lib.nixosSystem;
          };
          importModuleFiles =
            file:
            lib.genAttrs (moduleNamesWith file) (name: callWith args (import (./modules + "/${name}/${file}")));
        in
        prefixAttrs "pkgs" packages.${system}
        // prefixAttrs "module" (
          lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (importModuleFiles "check.nix")
        )
        // prefixAttrs "nixos" (lib.optionalAttrs (system == "x86_64-linux") (importModuleFiles "test.nix"))
        // {
          devshell-default = devShells.${system}.default;
          formatting = allPackages.${system}.formatter.tests.check;
        }
      );

      formatter = eachSystem (system: allPackages.${system}.formatter);
    };
}

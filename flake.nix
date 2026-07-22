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

      eachSystem =
        f:
        lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
          }
        );

      treefmtEval = eachSystem (
        { pkgs, ... }:
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs = {
            deadnix.enable = true;
            keep-sorted.enable = true;
            nixfmt.enable = true;
            statix.enable = true;
          };
        }
      );

      packages = eachSystem (
        { pkgs, ... }:
        import ./packages {
          inherit pkgs;
          craneLib = crane.mkLib pkgs;
        }
      );
    in
    {
      inherit packages;

      nixosModules = import ./modules;

      checks = eachSystem (
        { system, pkgs, ... }:
        {
          formatting = treefmtEval.${system}.config.build.check self;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          module-omnigraph = import ./modules/omnigraph/check.nix {
            inputs = { inherit nixpkgs; };
            inherit pkgs self system;
          };
        }
        // lib.mapAttrs' (name: lib.nameValuePair "package-${name}") packages.${system}
      );

      formatter = eachSystem ({ system, ... }: treefmtEval.${system}.config.build.wrapper);
    };
}

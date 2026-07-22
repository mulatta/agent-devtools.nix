{
  lib,
  stdenv,
  fetchFromGitHub,
  craneLib,
  cmake,
  pkg-config,
  protobuf,
  rustc,
  versionCheckHook,
}:

let
  version = "0.8.1";

  disableLanceU8Avx512Vnni =
    stdenv.hostPlatform.isx86_64 && lib.versionOlder rustc.llvm.version "22.0.0";

  src = fetchFromGitHub {
    owner = "ModernRelay";
    repo = "omnigraph";
    tag = "v${version}";
    hash = "sha256-pj52KVALQZgQrC0pJMHM0u3We1rQ/5zMR0UtGRO7hyg=";
  };

  cargoVendorDir = craneLib.vendorCargoDeps {
    inherit src;

    outputHashes = {
      "git+https://github.com/lance-format/lance?rev=f24e42c11a742581365e1cbe17c906ea2dac1bc6#f24e42c11a742581365e1cbe17c906ea2dac1bc6" =
        "sha256-+n5Fhopz7KfLFS4ZDQ1ONlHKIrYVQmxjkBEYXAO4Vro=";
    };

    overrideVendorGitCheckout =
      packages: checkout:
      if disableLanceU8Avx512Vnni && lib.any (package: package.name == "lance-linalg") packages then
        stdenv.mkDerivation {
          name = "${checkout.name}-disable-lance-u8-avx512-vnni";

          dontUnpack = true;
          dontConfigure = true;
          dontBuild = true;
          dontFixup = true;

          installPhase = ''
            mkdir -p "$out"
            cp -R ${checkout}/. "$out"/
            chmod -R u+w "$out"
            patch -p1 -d "$out" < ${./0001-lance-linalg-disable-u8-avx512-vnni.patch}
          '';
        }
      else
        checkout;
  };

  commonArgs = {
    pname = "omnigraph";
    inherit src version cargoVendorDir;

    strictDeps = true;

    nativeBuildInputs = [
      cmake
      pkg-config
      protobuf
    ];

    doCheck = false;
  };

  cargoArtifacts = craneLib.buildDepsOnly (
    commonArgs
    // {
      cargoExtraArgs = "-p omnigraph-cli -p omnigraph-server";
    }
  );

  mkPackage =
    {
      pname,
      cargoExtraArgs,
      installCheckCommand ? null,
      useVersionCheckHook ? false,
      description,
      mainProgram,
    }:
    craneLib.buildPackage (
      commonArgs
      // {
        inherit
          pname
          cargoArtifacts
          cargoExtraArgs
          ;

        doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
        nativeInstallCheckInputs = lib.optional useVersionCheckHook versionCheckHook;
        installCheckPhase = ''
          runHook preInstallCheck

          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"
          ${lib.optionalString (installCheckCommand != null) installCheckCommand}

          runHook postInstallCheck
        '';

        meta = {
          inherit description mainProgram;
          homepage = "https://github.com/ModernRelay/omnigraph";
          changelog = "https://github.com/ModernRelay/omnigraph/releases/tag/v${version}";
          license = lib.licenses.mit;
          maintainers = with lib.maintainers; [ mulatta ];
        };
      }
    );
in
{
  inherit
    mkPackage
    src
    version
    ;
}

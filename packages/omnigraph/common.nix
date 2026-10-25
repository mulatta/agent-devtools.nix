{
  lib,
  stdenv,
  fetchFromGitHub,
  craneLib,
  rustPlatform,
  runCommand,
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

  cargoHash = "sha256-2u781fSfXF3aDi69bwcpu6bVvAYsincKveumeR163No=";

  vendor = rustPlatform.fetchCargoVendor {
    inherit src;
    hash = cargoHash;
  };

  cargoVendorDir = runCommand "omnigraph-vendor" { } ''
    mkdir -p "$out"
    cp -R ${vendor}/. "$out"/
    chmod -R u+w "$out"
    # Crane reads source replacements from the vendor root, not .cargo.
    substitute "$out/.cargo/config.toml" "$out/config.toml" \
      --replace-fail '@vendor@' "$out"
    ${lib.optionalString disableLanceU8Avx512Vnni ''
      patch -p1 -d "$out/source-git-0" < ${./0001-lance-linalg-disable-u8-avx512-vnni.patch}
    ''}
  '';

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
      # Source discovery for dummy generation would require evaluation-time fetching.
      src = null;
      dummySrc = src;
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

        passthru = {
          skipUpdate = true;
          cargoDeps = vendor;
        };

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

{ pkgs, ... }:

pkgs.python3Packages.buildPythonApplication (finalAttrs: {
  pname = "cocoindex";
  version = "1.0.17";
  pyproject = true;

  src = pkgs.fetchPypi {
    inherit (finalAttrs) pname version;
    hash = "sha256-1Qj7qjtbge5rdBIUd6YMI8gSlld5vFFgFFpGndXfaq0=";
  };

  cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-VlZih5l0wshCU8dK2mO5UuhfrHchbjQduYXn7Ydkc5g=";
  };

  nativeBuildInputs = [
    pkgs.rustPlatform.cargoSetupHook
    pkgs.rustPlatform.maturinBuildHook
  ];

  buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    pkgs.libiconv
  ];

  dependencies = with pkgs.python3Packages; [
    click
    msgspec
    numpy
    psutil
    python-dotenv
    rich
    typing-extensions
    watchdog
  ];

  pythonImportsCheck = [
    "cocoindex"
    "cocoindex._internal.core"
  ];

  meta = {
    description = "Framework for building incremental data indexing pipelines for AI applications";
    homepage = "https://github.com/cocoindex-io/cocoindex";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "cocoindex";
    maintainers = [ ];
  };
})

{
  projectRootFile = "flake.nix";

  programs = {
    actionlint.enable = true;
    deadnix.enable = true;
    keep-sorted.enable = true;
    mypy = {
      enable = true;
      directories = {
        ci = {
          directory = ".github/ci";
          modules = [ "." ];
          options = [ "--strict" ];
        };
        omnigraph-updater = {
          directory = "packages/omnigraph";
          modules = [ "." ];
          options = [ "--strict" ];
        };
      };
    };
    nixfmt.enable = true;
    ruff-check.enable = true;
    ruff-format.enable = true;
    shellcheck = {
      enable = true;
      excludes = [ ".envrc" ];
    };
    statix.enable = true;
  };

  settings.formatter = {
    mypy-ci = {
      includes = [ ".github/ci/*.py" ];
      pipeline = "python";
      priority = 3;
    };
    mypy-omnigraph-updater = {
      includes = [ "packages/omnigraph/update.py" ];
      pipeline = "python";
      priority = 3;
    };
    ruff-check = {
      pipeline = "python";
      priority = 1;
    };
    ruff-format = {
      pipeline = "python";
      priority = 2;
    };
  };
}

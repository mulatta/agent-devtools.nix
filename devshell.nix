{ formatter, pkgs }:

pkgs.mkShellNoCC {
  packages = [
    pkgs.bash
    pkgs.coreutils
    pkgs.gh
    pkgs.git
    pkgs.nix-update
    pkgs.python3
    formatter
  ];

  shellHook = ''
    export PRJ_ROOT="$PWD"
  '';
}

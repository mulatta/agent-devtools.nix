#!/usr/bin/env python3
"""Update all Omnigraph outputs through their shared source definition."""

import subprocess


def main() -> None:
    """Update the Linux bundle, which owns the shared CLI/server source pin."""
    subprocess.run(
        [
            "nix-update",
            "--flake",
            "omnigraph",
            "--use-github-releases",
        ],
        check=True,
    )


if __name__ == "__main__":
    main()

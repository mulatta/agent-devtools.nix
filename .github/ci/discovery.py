#!/usr/bin/env python3
"""Discover packages eligible for automated updates."""

import json
import logging
import os
import subprocess
from dataclasses import asdict, dataclass

from lib import write_output

log = logging.getLogger(__name__)

NIX_EXPR = """
packages:
  builtins.mapAttrs
    (_name: package:
      if package ? version && !(package.passthru.skipUpdate or false)
      then package.version
      else null)
    packages
"""


@dataclass(frozen=True, slots=True)
class MatrixItem:
    """GitHub Actions matrix entry."""

    name: str
    current_version: str


def discover_packages(package_filter: list[str] | None) -> list[MatrixItem]:
    """Evaluate updateable x86_64-linux package versions once."""
    result = subprocess.run(
        [
            "nix",
            "eval",
            "--json",
            ".#packages.x86_64-linux",
            "--apply",
            NIX_EXPR,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        log.error("Package discovery failed: %s", result.stderr.strip())
        raise SystemExit(1)

    versions: dict[str, str | None] = json.loads(result.stdout)
    selected = set(package_filter) if package_filter else None
    items = [
        MatrixItem(name=name, current_version=version)
        for name, version in sorted(versions.items())
        if version is not None and (selected is None or name in selected)
    ]

    if selected is not None:
        found = {item.name for item in items}
        for name in sorted(selected - found):
            log.warning("Package %s not found or excluded from updates", name)

    return items


def main() -> None:
    """Emit package update matrix for GitHub Actions."""
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    package_filter = os.environ.get("PACKAGES", "").split() or None
    items = discover_packages(package_filter)
    matrix = {"include": [asdict(item) for item in items]}

    write_output("matrix", json.dumps(matrix, separators=(",", ":")))
    write_output("has-updates", str(bool(items)).lower())

    if items:
        log.info("Discovered packages: %s", ", ".join(item.name for item in items))
    else:
        log.info("No updateable packages discovered")


if __name__ == "__main__":
    main()

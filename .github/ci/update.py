#!/usr/bin/env python3
"""Update one package and report resulting version to GitHub Actions."""

import argparse
import logging
import subprocess
import sys
from pathlib import Path

from lib import nix_eval_raw, run, write_output

log = logging.getLogger(__name__)


def git_has_changes() -> bool:
    """Return whether updater changed tracked or untracked files."""
    result = run(["git", "status", "--porcelain"], capture=True)
    return bool(result.stdout.strip())


def run_update_command(cmd: list[str], package: str) -> None:
    """Run updater while streaming combined output on completion."""
    result = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.returncode != 0:
        log.error("::error::Update failed for package %s", package)
        raise SystemExit(result.returncode)


def load_nix_update_args(package: str) -> list[str]:
    """Load package-specific nix-update arguments."""
    args_file = Path("packages") / package / "nix-update-args"
    if not args_file.exists():
        return []
    return [
        stripped
        for line in args_file.read_text().splitlines()
        if (stripped := line.strip()) and not stripped.startswith("#")
    ]


def update_package(package: str) -> None:
    """Run custom updater when present, otherwise nix-update."""
    update_script = Path("packages") / package / "update.py"
    if update_script.exists():
        cmd = [sys.executable, str(update_script)]
    else:
        cmd = ["nix-update", "--flake", package, *load_nix_update_args(package)]

    log.info("Running: %s", " ".join(cmd))
    run_update_command(cmd, package)

    if not git_has_changes():
        log.info("Package %s already up to date", package)
        write_output("updated", "false")
        return

    attribute = f".#packages.x86_64-linux.{package}"
    new_version = nix_eval_raw(f"{attribute}.version") or "unknown"
    changelog = nix_eval_raw(f"{attribute}.meta.changelog") or ""

    write_output("updated", "true")
    write_output("new_version", new_version)
    write_output("changelog", changelog)


def main() -> None:
    """Parse package name and perform update."""
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package")
    args = parser.parse_args()
    update_package(args.package)


if __name__ == "__main__":
    main()

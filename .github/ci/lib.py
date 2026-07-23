"""Shared helpers for package update automation."""

import logging
import os
import subprocess
from pathlib import Path

log = logging.getLogger(__name__)


def run(
    cmd: list[str],
    *,
    check: bool = True,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    """Run command, optionally capturing text output."""
    return subprocess.run(cmd, capture_output=capture, text=True, check=check)


def write_output(key: str, value: str) -> None:
    """Write GitHub Actions output or log value during local runs."""
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with Path(github_output).open("a") as output:
            output.write(f"{key}={value}\n")
    else:
        log.info("output: %s=%s", key, value)


def nix_eval_raw(attribute: str) -> str | None:
    """Evaluate raw flake attribute, returning None when unavailable."""
    result = run(["nix", "eval", attribute, "--raw"], check=False, capture=True)
    return result.stdout.strip() if result.returncode == 0 else None

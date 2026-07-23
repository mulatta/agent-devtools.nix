#!/usr/bin/env python3
"""Commit package update and create or refresh its pull request."""

import argparse
import logging
import os

from lib import run

log = logging.getLogger(__name__)


def find_pr(branch: str) -> str | None:
    """Return open pull request number for branch."""
    result = run(
        [
            "gh",
            "pr",
            "list",
            "--head",
            branch,
            "--state",
            "open",
            "--json",
            "number",
            "--jq",
            ".[0].number // empty",
        ],
        capture=True,
    )
    return result.stdout.strip() or None


def create_or_update_pr(
    package: str,
    current_version: str,
    new_version: str,
    changelog: str,
) -> None:
    """Format, commit, push, and create or update package PR."""
    branch = f"update/{package}"
    title = f"{package}: {current_version} -> {new_version}"
    body = f"Automated update of {package} from {current_version} to {new_version}."
    commit_message = f"{title}\n\n{changelog}" if changelog else title

    run(["nix", "fmt"])
    run(["git", "add", "-A"])
    run(["git", "commit", "-m", commit_message])
    run(["git", "push", "--force-with-lease", "origin", f"HEAD:{branch}"])

    pr_number = find_pr(branch)
    if pr_number:
        log.info("Updating PR #%s", pr_number)
        run(["gh", "pr", "edit", pr_number, "--title", title, "--body", body])
    else:
        command = [
            "gh",
            "pr",
            "create",
            "--base",
            os.environ.get("BASE_BRANCH", "main"),
            "--head",
            branch,
            "--title",
            title,
            "--body",
            body,
        ]
        for label in os.environ.get("PR_LABELS", "").split(","):
            if stripped := label.strip():
                command.extend(["--label", stripped])
        run(command)
        pr_number = find_pr(branch)

    if os.environ.get("AUTO_MERGE") == "true" and pr_number:
        run(["gh", "pr", "merge", pr_number, "--auto", "--squash"], check=False)


def main() -> None:
    """Parse update metadata and publish pull request."""
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package")
    parser.add_argument("current_version")
    parser.add_argument("new_version")
    args = parser.parse_args()

    create_or_update_pr(
        args.package,
        args.current_version,
        args.new_version,
        os.environ.get("CHANGELOG_URL", ""),
    )


if __name__ == "__main__":
    main()

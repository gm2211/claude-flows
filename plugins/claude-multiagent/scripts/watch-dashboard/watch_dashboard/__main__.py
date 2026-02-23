"""Entry point for python -m watch_dashboard."""

from __future__ import annotations

import argparse
import logging
import os

from .app import WatchDashboardApp
from .providers import default_providers_dir


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Watch Dashboard — Textual TUI for deploys and GitHub Actions"
    )
    parser.add_argument(
        "--project-dir",
        type=str,
        default=None,
        help="Project directory (defaults to git root or cwd)",
    )
    parser.add_argument(
        "--dash-id",
        type=str,
        default="",
        help="Dashboard instance ID (for Zellij pane management)",
    )
    parser.add_argument(
        "--providers-dir",
        type=str,
        default=None,
        help="Path to providers directory",
    )

    args = parser.parse_args()

    # Resolve project dir
    project_dir = args.project_dir
    if not project_dir:
        import subprocess
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                project_dir = result.stdout.strip()
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
    if not project_dir:
        project_dir = os.getcwd()

    # Setup logging
    log = logging.getLogger("watch-dashboard")
    log.setLevel(logging.DEBUG)
    log.propagate = False
    if not log.handlers:
        fh = logging.FileHandler("/tmp/watch-dashboard.log")
        fh.setFormatter(logging.Formatter(
            "%(asctime)s %(levelname)s %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
        ))
        log.addHandler(fh)

    providers_dir = args.providers_dir or default_providers_dir()

    app = WatchDashboardApp(
        project_dir=project_dir,
        providers_dir=providers_dir,
        dash_id=args.dash_id,
    )
    app.run()


if __name__ == "__main__":
    main()

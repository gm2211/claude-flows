"""Config file helpers for .deploy-watch.json."""

from __future__ import annotations

import json
import logging
import os

_log = logging.getLogger("watch-dashboard")


def config_read(config_file: str) -> dict:
    """Read and parse the config file. Returns dict or empty dict."""
    try:
        with open(config_file, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def config_write(config_file: str, data: dict) -> None:
    """Write config data to the config file."""
    with open(config_file, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def config_get_provider(config_file: str) -> str | None:
    """Return the configured provider name, or None."""
    cfg = config_read(config_file)
    return cfg.get("provider") or None


def config_remove(config_file: str) -> None:
    """Remove the config file entirely."""
    try:
        os.remove(config_file)
    except FileNotFoundError:
        pass

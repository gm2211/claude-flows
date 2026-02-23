"""Provider discovery, configuration, and deploy fetching."""

from __future__ import annotations

import json
import logging
import os
import subprocess
import time

from .config import config_read

_log = logging.getLogger("watch-dashboard")


def default_providers_dir() -> str:
    """Find providers directory relative to this package.

    Layout: watch-dashboard/watch_dashboard/providers.py
    Providers: scripts/providers/
    """
    scripts_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    # scripts_dir = watch-dashboard/, go up one more to scripts/
    scripts_dir = os.path.dirname(scripts_dir)
    return os.path.join(scripts_dir, "providers")


def list_providers(providers_dir: str) -> list[str]:
    """List available provider scripts (executable files in providers dir)."""
    providers: list[str] = []
    if not os.path.isdir(providers_dir):
        return providers
    for fname in sorted(os.listdir(providers_dir)):
        fpath = os.path.join(providers_dir, fname)
        if not os.path.isfile(fpath) or not os.access(fpath, os.X_OK):
            continue
        if fname.startswith("README") or fname.endswith(".md"):
            continue
        providers.append(fname)
    return providers


def provider_display_name(provider: str, providers_dir: str) -> str:
    """Get the human-readable name of a provider."""
    script = os.path.join(providers_dir, provider)
    if not os.access(script, os.X_OK):
        return provider
    try:
        result = subprocess.run(
            [script, "name"], capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return provider


def provider_config_fields(provider: str, providers_dir: str) -> list[dict]:
    """Get config fields for a provider.

    Returns list of dicts with keys: key, label, required, default.
    """
    script = os.path.join(providers_dir, provider)
    if not os.access(script, os.X_OK):
        return []
    try:
        result = subprocess.run(
            [script, "config"], capture_output=True, text=True, timeout=5
        )
        if result.returncode != 0:
            return []
        data = json.loads(result.stdout)
        fields = data.get("fields", [])
        for f in fields:
            f.setdefault("required", False)
            f.setdefault("default", "")
        return fields
    except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError):
        return []


def fetch_deploys(config_file: str, providers_dir: str) -> list[dict] | None:
    """Call the configured provider's list command and return parsed records.

    Returns list of records on success, None on error.
    """
    cfg = config_read(config_file)
    provider = cfg.get("provider")
    if not provider:
        _log.debug("fetch_deploys: no provider configured")
        return []

    script = os.path.join(providers_dir, provider)
    if not os.access(script, os.X_OK):
        _log.warning("fetch_deploys: provider script not executable: %s", script)
        return []

    fields = provider_config_fields(provider, providers_dir)
    env = os.environ.copy()
    provider_cfg = cfg.get(provider, {})

    for field in fields:
        key = field["key"]
        val = provider_cfg.get(key, field.get("default", ""))
        env_key = f"DEPLOY_WATCH_{key.upper()}"
        env[env_key] = str(val)

    _log.debug("fetch_deploys: calling %s list", script)
    try:
        result = subprocess.run(
            [script, "list"], capture_output=True, text=True,
            timeout=30, env=env
        )
        if result.stderr.strip():
            _log.debug("fetch_deploys: stderr: %s", result.stderr.strip())
        if result.returncode != 0:
            _log.warning("fetch_deploys: provider exited %d", result.returncode)
            return None
        records: list[dict] = []
        for line in result.stdout.strip().split("\n"):
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                _log.warning("fetch_deploys: bad JSON line: %s", line[:120])
        _log.debug("fetch_deploys: parsed %d records", len(records))
        return records
    except subprocess.TimeoutExpired:
        _log.error("fetch_deploys: provider timed out after 30s")
        return None
    except FileNotFoundError:
        _log.error("fetch_deploys: provider script not found: %s", script)
        return None


# ---------------------------------------------------------------------------
# Time helpers (ported from watch-deploys.py)
# ---------------------------------------------------------------------------

def elapsed_since(start_epoch: int | str) -> str:
    """Format elapsed time from a unix epoch to now."""
    try:
        start = int(start_epoch)
    except (ValueError, TypeError):
        return str(start_epoch)
    diff = max(0, int(time.time()) - start)
    if diff < 60:
        return f"{diff}s"
    elif diff < 3600:
        return f"{diff // 60}m {diff % 60}s"
    else:
        return f"{diff // 3600}h {(diff % 3600) // 60}m"


def format_elapsed(record: dict) -> str:
    """Format the elapsed/duration column for a deploy record."""
    build_started = record.get("build_started", "")
    deploy_finished = record.get("deploy_finished", "")

    if not build_started:
        return ""

    try:
        start = int(build_started)
    except (ValueError, TypeError):
        return str(build_started)

    if deploy_finished:
        try:
            end = int(deploy_finished)
            dur = max(0, end - start)
            if dur < 60:
                return f"{dur}s"
            elif dur < 3600:
                return f"{dur // 60}m {dur % 60}s"
            else:
                return f"{dur // 3600}h {(dur % 3600) // 60}m"
        except (ValueError, TypeError):
            pass

    return f"{elapsed_since(build_started)} ago"

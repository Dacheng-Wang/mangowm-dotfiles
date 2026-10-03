#!/usr/bin/env python3
"""Apply workspace defaults at login and when an output reappears."""

import fcntl
import json
import logging
import os
from pathlib import Path
import subprocess
import time


DEFAULTS = {"HDMI-A-2": 2, "HDMI-A-1": 1}


def ipc(*args):
    result = subprocess.run(
        ["mmsg", *args], capture_output=True, text=True, timeout=3
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return json.loads(result.stdout) if args[0] == "get" else None


def apply_default(name, tag):
    snapshot = ipc("get", "all-monitors")["monitors"]
    monitor = next((m for m in snapshot if m["name"] == name), None)
    if monitor is None:
        return False
    if monitor.get("active_tags") == [tag]:
        return True
    focused = next((m["name"] for m in snapshot if m.get("active")), None)
    try:
        for _ in range(10):
            ipc("dispatch", f"viewcrossmon,{tag},{name}")
            if ipc("get", "monitor", name).get("active_tags") == [tag]:
                logging.info("Restored %s to workspace %s", name, tag)
                return True
            time.sleep(0.2)
        logging.error("Could not restore %s to workspace %s", name, tag)
        return False
    finally:
        if focused and focused != name:
            ipc("dispatch", f"focusmon,{focused}")


def main():
    logging.basicConfig(level=logging.INFO, format="workspace-watcher: %(message)s")
    # One watcher per compositor session, including when started manually.
    socket = os.environ.get("MANGO_INSTANCE_SIGNATURE", "mango")
    lock_path = Path(os.environ["XDG_RUNTIME_DIR"]) / (Path(socket).name + ".workspaces.lock")
    with lock_path.open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return

        for attempt in range(150):
            try:
                ipc("get", "version")
                break
            except (RuntimeError, subprocess.TimeoutExpired, ValueError):
                if attempt == 149:
                    raise RuntimeError("Mango IPC did not become available")
                time.sleep(0.2)

        present = set()
        while True:
            # Subscribe before applying defaults to capture hotplug events
            # that arrive while the initial defaults are being applied.
            with subprocess.Popen(
                ["mmsg", "watch", "all-monitors"], stdout=subprocess.PIPE, text=True
            ) as watcher:
                try:
                    for line in watcher.stdout:
                        try:
                            snapshot = json.loads(line)
                            if "monitors" not in snapshot:
                                continue
                            current = {m["name"] for m in snapshot["monitors"]}
                            added = current - present
                            present = current
                            for name, tag in DEFAULTS.items():
                                if name in added:
                                    try:
                                        apply_default(name, tag)
                                    except (RuntimeError, subprocess.TimeoutExpired, ValueError) as error:
                                        logging.error("%s: %s", name, error)
                        except (ValueError, KeyError, TypeError) as error:
                            logging.error("Invalid monitor event: %s", error)
                finally:
                    if watcher.poll() is None:
                        watcher.terminate()
                    watcher.wait()
            # Recover a dropped stream without resetting connected monitors.
            time.sleep(0.5)
            try:
                ipc("get", "version")
            except (RuntimeError, subprocess.TimeoutExpired, ValueError):
                return


if __name__ == "__main__":
    main()

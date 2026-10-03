#!/usr/bin/env bash
# Keep the login entry point stable; the watcher handles reconnects too.
exec /usr/bin/python3 "$(dirname -- "$0")/watch-workspaces.py"

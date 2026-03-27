#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_DIR="$ROOT_DIR/.run"

stop_pid_file() {
  local file="$1"
  local label="$2"

  if [[ -f "$file" ]]; then
    local pid
    pid="$(cat "$file")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "[stop_all] Stopping $label (PID $pid)"
      kill "$pid" || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$file"
  fi
}

stop_pid_file "$RUN_DIR/backend.pid" "backend"
stop_pid_file "$RUN_DIR/ai.pid" "ai"

echo "[stop_all] Done."

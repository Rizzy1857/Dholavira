#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_DIR="$ROOT_DIR/.run"
mkdir -p "$RUN_DIR"

start_backend() {
  echo "[run_all] Starting backend..."
  cd "$ROOT_DIR/backend"
  if [[ ! -d node_modules ]]; then
    npm install
  fi

  if [[ -f "$RUN_DIR/backend.pid" ]] && kill -0 "$(cat "$RUN_DIR/backend.pid")" 2>/dev/null; then
    echo "[run_all] Backend already running (PID $(cat "$RUN_DIR/backend.pid"))"
  else
    nohup npm run start > "$RUN_DIR/backend.log" 2>&1 &
    echo $! > "$RUN_DIR/backend.pid"
    echo "[run_all] Backend PID $(cat "$RUN_DIR/backend.pid")"
  fi
}

start_ai() {
  echo "[run_all] Starting AI service..."
  cd "$ROOT_DIR/ai"

  if curl -fsS "http://127.0.0.1:5001/healthz" >/dev/null 2>&1; then
    echo "[run_all] AI already healthy on port 5001"
    return
  fi

  if [[ ! -d .venv ]]; then
    python3 -m venv .venv
  fi

  source .venv/bin/activate
  if ! python -c "import flask, requests, joblib" >/dev/null 2>&1; then
    pip install -r requirements.txt
  fi

  if [[ -f "$RUN_DIR/ai.pid" ]] && kill -0 "$(cat "$RUN_DIR/ai.pid")" 2>/dev/null; then
    echo "[run_all] AI already running (PID $(cat "$RUN_DIR/ai.pid"))"
  else
    local stale_pid
    stale_pid="$(lsof -ti tcp:5001 -sTCP:LISTEN 2>/dev/null | head -n 1 || true)"
    if [[ -n "$stale_pid" ]]; then
      echo "[run_all] Clearing stale listener on 5001 (PID $stale_pid)"
      kill "$stale_pid" 2>/dev/null || true
      sleep 1
      kill -9 "$stale_pid" 2>/dev/null || true
    fi

    nohup .venv/bin/python app.py > "$RUN_DIR/ai.log" 2>&1 &
    echo $! > "$RUN_DIR/ai.pid"
    echo "[run_all] AI PID $(cat "$RUN_DIR/ai.pid")"
  fi
}

wait_for_http() {
  local url="$1"
  local name="$2"
  local retries=40
  local sleep_s=1

  echo "[run_all] Waiting for $name at $url ..."
  for ((i=1; i<=retries; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "[run_all] $name is up"
      return 0
    fi
    sleep "$sleep_s"
  done

  echo "[run_all] WARNING: $name did not become healthy in time"
  return 1
}

start_backend
start_ai
wait_for_http "http://127.0.0.1:3000/healthz" "backend" || true
wait_for_http "http://127.0.0.1:5001/" "ai" || true
echo "[run_all] Services started. Open web app at http://127.0.0.1:3000/"

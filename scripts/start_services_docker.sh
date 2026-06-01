#!/usr/bin/env bash
set -e

###############################################################################
### CONFIGURATION
###############################################################################

BASE_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
ENV_FILE="$BASE_DIR/api/.env"

ARQ_WORKERS=${ARQ_WORKERS:-1}
FASTAPI_WORKERS=${FASTAPI_WORKERS:-1}
UVICORN_BASE_PORT=${UVICORN_BASE_PORT:-8000}

cd "$BASE_DIR"
echo "Starting Dograh Services (DOCKER) at $(date) in BASE_DIR: ${BASE_DIR}"

###############################################################################
### 1) Load env file if mounted (env normally comes from docker-compose)
###############################################################################

if [[ -f "$ENV_FILE" ]]; then
  set -a && . "$ENV_FILE" && set +a
fi

###############################################################################
### 2) Normalize deployment environment
###############################################################################

first_non_empty() {
  local value
  for value in "$@"; do
    if [[ -n "${value:-}" ]]; then
      printf '%s' "$value"
      return 0
    fi
  done
  return 1
}

# Coolify and managed providers often expose equivalent values under different
# names. Normalize them before importing Python modules that read env at import.
export DATABASE_URL="${DATABASE_URL:-$(first_non_empty "${POSTGRES_URL:-}" "${DATABASE_PRIVATE_URL:-}" "${SUPABASE_DATABASE_URL:-}" "${SUPABASE_DB_URL:-}" || true)}"

if [[ -z "${DATABASE_URL:-}" && -n "${SUPABASE_URL:-}" ]]; then
  SUPABASE_DB_PASSWORD_VALUE="$(first_non_empty "${SUPABASE_DB_PASSWORD:-}" "${SUPABASE_DATABASE_PASSWORD:-}" "${SUPABASE_PASSWORD:-}" "${POSTGRES_PASSWORD:-}" || true)"
  if [[ -n "$SUPABASE_DB_PASSWORD_VALUE" ]]; then
    export DATABASE_URL="$(
      SUPABASE_URL="$SUPABASE_URL" SUPABASE_DB_PASSWORD="$SUPABASE_DB_PASSWORD_VALUE" python - <<'PY'
from urllib.parse import quote, urlparse
import os

host = urlparse(os.environ["SUPABASE_URL"]).hostname or ""
project_ref = host.split(".")[0]
password = quote(os.environ["SUPABASE_DB_PASSWORD"], safe="")
print(f"postgresql+asyncpg://postgres:{password}@db.{project_ref}.supabase.co:5432/postgres")
PY
    )"
  fi
fi

export REDIS_URL="${REDIS_URL:-$(first_non_empty "${REDIS_PRIVATE_URL:-}" "${COOLIFY_REDIS_URL:-}" "${UPSTASH_REDIS_URL:-}" || true)}"

# Supabase S3 aliases used by the RapidXAI bridge env.
export AWS_ENDPOINT_URL="${AWS_ENDPOINT_URL:-${SUPABASE_S3_ENDPOINT:-}}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-${SUPABASE_S3_ACCESS_KEY_ID:-}}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-${SUPABASE_S3_SECRET_ACCESS_KEY:-}}"
export S3_REGION="${S3_REGION:-${SUPABASE_S3_REGION:-us-east-1}}"
export S3_BUCKET="${S3_BUCKET:-${SUPABASE_S3_BUCKET:-}}"
if [[ -n "${AWS_ENDPOINT_URL:-}" && -n "${S3_BUCKET:-}" ]]; then
  export ENABLE_AWS_S3="${ENABLE_AWS_S3:-true}"
fi

missing_env=()
[[ -n "${DATABASE_URL:-}" ]] || missing_env+=("DATABASE_URL")
[[ -n "${REDIS_URL:-}" ]] || missing_env+=("REDIS_URL")
if [[ "${ENABLE_AWS_S3:-false}" == "true" ]]; then
  [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] || missing_env+=("AWS_ACCESS_KEY_ID")
  [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] || missing_env+=("AWS_SECRET_ACCESS_KEY")
  [[ -n "${S3_BUCKET:-}" ]] || missing_env+=("S3_BUCKET")
fi

if (( ${#missing_env[@]} > 0 )); then
  echo "ERROR: Missing required runtime environment variable(s): ${missing_env[*]}" >&2
  echo "Set them in Coolify runtime environment variables, not only build arguments." >&2
  echo "Supported aliases: POSTGRES_URL/DATABASE_PRIVATE_URL/SUPABASE_DATABASE_URL for DATABASE_URL; REDIS_PRIVATE_URL/COOLIFY_REDIS_URL/UPSTASH_REDIS_URL for REDIS_URL." >&2
  echo "Supabase Postgres can also be derived from SUPABASE_URL + SUPABASE_DB_PASSWORD." >&2
  exit 78
fi

###############################################################################
### 3) Run migrations
###############################################################################

alembic -c "$BASE_DIR/api/alembic.ini" upgrade head

###############################################################################
### 4) Signal handling — forward TERM/INT to children for clean docker stop
###############################################################################

pids=()

shutdown() {
  echo "Received shutdown signal, stopping services..."
  for pid in "${pids[@]}"; do
    kill -TERM "$pid" 2>/dev/null || true
  done
  wait
  exit 0
}

trap shutdown TERM INT

start() {
  local name=$1
  shift
  echo "→ Starting $name"
  "$@" &
  pids+=($!)
  echo "  $name PID $!"
}

###############################################################################
### 5) Start services (logs go to stdout for `docker logs`)
###############################################################################

start ari_manager           python -m api.services.telephony.ari_manager
start campaign_orchestrator python -m api.services.campaign.campaign_orchestrator

# Spawn FASTAPI_WORKERS independent uvicorn processes on consecutive ports
# starting at UVICORN_BASE_PORT. nginx upstream (configured in setup_remote.sh)
# balances across them with least_conn — better than uvicorn --workers for
# long-lived WebSocket connections, which would otherwise stick to whichever
# worker accepted them first.
for ((i=0; i<FASTAPI_WORKERS; i++)); do
  port=$((UVICORN_BASE_PORT + i))
  start "uvicorn$i" uvicorn api.app:app --host 0.0.0.0 --port "$port" --workers 1
done

for ((i=1; i<=ARQ_WORKERS; i++)); do
  start "arq$i" python -m arq api.tasks.arq.WorkerSettings --custom-log-dict api.tasks.arq.LOG_CONFIG
done

###############################################################################
### 6) Wait — if any service exits, tear the container down so docker restarts
###############################################################################

wait -n
echo "A service exited; tearing down container."
shutdown

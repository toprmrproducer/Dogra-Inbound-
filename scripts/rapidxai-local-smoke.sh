#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILES=(-f docker-compose.yaml -f docker-compose-local.yaml -f docker-compose.override.yml)
API_URL=${API_URL:-http://localhost:8000}
USER_ID=${USER_ID:-1}
USER_EMAIL=${USER_EMAIL:-shreyas@gmail.com}
TEST_PHONE_NUMBER=${TEST_PHONE_NUMBER:-}

echo "[1/8] API health"
curl -fsS "$API_URL/api/v1/health" | jq '{status,version,auth_provider,deployment_mode}'

echo "[2/8] Mint local auth token for smoke user $USER_EMAIL"
TOKEN=$(docker compose "${COMPOSE_FILES[@]}" exec -T api python -W ignore -c "from api.utils.auth import create_jwt_token; print(create_jwt_token($USER_ID, '$USER_EMAIL'))" | tail -n 1)

echo "[3/8] Auth check"
curl -fsS -H "Authorization: Bearer $TOKEN" "$API_URL/api/v1/auth/me" | jq '{id,email,organization_id}'

echo "[4/8] Model configuration save check"
CONFIG_BODY='{"is_realtime":true,"realtime":{"provider":"google_realtime","model":"gemini-3.1-flash-live-preview","voice":"Charon","language":"en","api_key":["***********************************HjIE"]}}'
curl -fsS -X PUT -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' "$API_URL/api/v1/user/configurations/user" -d "$CONFIG_BODY" | jq '{is_realtime,realtime:{provider:.realtime.provider,model:.realtime.model,voice:.realtime.voice,language:.realtime.language}}'

echo "[5/8] Telephony configuration check"
curl -fsS -H "Authorization: Bearer $TOKEN" "$API_URL/api/v1/organizations/telephony-configs" | jq '{count:(.configurations | length), configurations:[.configurations[] | {id,name,provider,is_default_outbound}]}'

echo "[6/8] Create dental inbound agent from template"
WORKFLOW_ID=$(curl -fsS -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' "$API_URL/api/v1/workflow/create/template" \
  -d '{"call_type":"inbound","use_case":"RapidXAI Dental Clinic Smoke Agent","activity_description":"Answer inbound dental clinic inquiries, collect patient name and phone, understand appointment needs, and offer to book an appointment."}' | jq -r '.id')
echo "workflow_id=$WORKFLOW_ID"

echo "[7/8] Create web-call run for the agent"
RUN_ID=$(curl -fsS -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' "$API_URL/api/v1/workflow/$WORKFLOW_ID/runs" \
  -d '{"mode":"small_webrtc","name":"RapidXAI local smoke web call"}' | jq -r '.id')
echo "run_id=$RUN_ID"
echo "web_call_url=http://localhost:3010/workflow/$WORKFLOW_ID/run/$RUN_ID"

echo "[8/8] MinIO/S3-compatible storage check"
docker compose "${COMPOSE_FILES[@]}" exec -T api python - <<'PY'
import asyncio
from io import BytesIO
from api.services.storage import storage_fs

async def main():
    path = "health/rapidxai-storage-check.txt"
    ok = await storage_fs.acreate_file(path, BytesIO(b"rapidxai storage ok"))
    meta = await storage_fs.aget_file_metadata(path)
    url = await storage_fs.aget_signed_url(path)
    print({"write_ok": ok, "metadata_ok": bool(meta), "url": url})

asyncio.run(main())
PY

if [[ -n "$TEST_PHONE_NUMBER" ]]; then
  echo "Optional real outbound call requested via TEST_PHONE_NUMBER. This may incur provider cost."
  curl -fsS -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' "$API_URL/api/v1/telephony/initiate-call" \
    -d "{\"workflow_id\":$WORKFLOW_ID,\"phone_number\":\"$TEST_PHONE_NUMBER\"}" | jq .
fi

echo "Smoke test passed."

# RapidXAI VPS Deployment

This deploys the local RapidXAI/Dograh stack on a VPS with Docker Compose: Postgres + pgvector, Redis, MinIO S3-compatible storage, API, and UI.

## Local URLs

- UI: `http://localhost:3010`
- API health: `http://localhost:8000/api/v1/health`
- MinIO console: `http://localhost:9001`

## VPS Requirements

- Ubuntu 22.04 or 24.04 VPS with 2+ CPU, 4 GB+ RAM, 30 GB+ disk
- Docker and Docker Compose plugin
- A domain or subdomain pointed to the VPS
- Open firewall ports: `80`, `443`; optionally restrict direct `3010`, `8000`, `9000`, `9001`

## 1. Install Docker

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
```

## 2. Copy Repo To VPS

```bash
git clone <your-repo-url> rapidxai
cd rapidxai
```

If you are copying from this machine instead of Git:

```bash
rsync -av --exclude .git --exclude venv --exclude node_modules ./ user@YOUR_VPS_IP:/opt/rapidxai/
```

## 3. Create Production Env

Create `.env` on the VPS:

```bash
POSTGRES_PASSWORD=replace_with_strong_password
REDIS_PASSWORD=replace_with_strong_password
OSS_JWT_SECRET=replace_with_64_random_chars
BACKEND_API_ENDPOINT=https://api.yourdomain.com
UI_APP_URL=https://app.yourdomain.com
MINIO_ACCESS_KEY=rapidxai_minio_admin
MINIO_SECRET_KEY=replace_with_strong_password
MINIO_BUCKET=voice-audio
```

Important: do not change `OSS_JWT_SECRET` after users log in. Changing it invalidates existing sessions.

## 4. Start The Stack

```bash
docker compose -f docker-compose.rapidxai-vps.yml up -d --build
```

Verify:

```bash
docker compose -f docker-compose.rapidxai-vps.yml ps
curl -fsS http://localhost:8000/api/v1/health | jq .
```

## 5. Add HTTPS Reverse Proxy

Use Caddy or Nginx. Example Caddyfile:

```caddy
app.yourdomain.com {
  reverse_proxy 127.0.0.1:3010
}

api.yourdomain.com {
  reverse_proxy 127.0.0.1:8000
}

storage.yourdomain.com {
  reverse_proxy 127.0.0.1:9000
}
```

Then set `.env` values to the HTTPS domains and restart:

```bash
docker compose -f docker-compose.rapidxai-vps.yml up -d --build
```

## 6. Configure App

1. Sign up or sign in on `https://app.yourdomain.com`.
2. Go to Models and enable Realtime Mode.
3. Provider: `google_realtime`.
4. Model: Gemini Live model shown in the UI.
5. Add your Gemini API key.
6. Go to Telephony and create the Vobiz configuration.
7. Set it as default outbound.
8. Add inbound phone numbers if you want inbound routing.
9. Create an agent from Voice Agents.
10. Use Web Call first, then use Phone Call for real outbound calls.

## 7. Smoke Test

On local or VPS:

```bash
./scripts/rapidxai-local-smoke.sh
```

Optional real outbound call test:

```bash
TEST_PHONE_NUMBER=+91XXXXXXXXXX ./scripts/rapidxai-local-smoke.sh
```

## 8. Backups

Postgres backup:

```bash
docker compose -f docker-compose.rapidxai-vps.yml exec -T postgres pg_dump -U postgres postgres > rapidxai-backup.sql
```

MinIO data is in the Docker volume `rapidxai_minio_data`. Back up this volume or migrate storage to a managed S3-compatible provider.

## 9. Operational Commands

```bash
docker compose -f docker-compose.rapidxai-vps.yml logs -f api
docker compose -f docker-compose.rapidxai-vps.yml logs -f ui
docker compose -f docker-compose.rapidxai-vps.yml restart api ui
docker compose -f docker-compose.rapidxai-vps.yml pull
docker compose -f docker-compose.rapidxai-vps.yml up -d --build
```

## Current Local Status

The current local stack uses MinIO for S3-compatible storage. Supabase S3 credentials can be swapped in later by setting `ENABLE_AWS_S3=true`, `AWS_ENDPOINT_URL`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET`, and `S3_REGION` in the API environment.

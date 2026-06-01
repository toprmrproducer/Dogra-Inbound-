# Coolify defaults to building ./Dockerfile from the repository root.
# Dograh keeps the API and UI Dockerfiles under api/ and ui/, so this root
# Dockerfile intentionally builds the API service for single-container deploys.
# For full-stack deployments, use docker-compose.rapidxai-vps.yml instead.

# Stage 1: Builder - Install Python dependencies
FROM python:3.12-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY api/requirements.txt .

RUN pip install --user --no-cache-dir -r requirements.txt && \
    rm -rf /root/.cache/pip

COPY pipecat /tmp/pipecat
RUN pip install --user --no-cache-dir '/tmp/pipecat[cartesia,deepgram,openai,elevenlabs,groq,google,azure,sarvam,soundfile,silero,webrtc,speechmatics,openrouter,camb]' && \
    pip uninstall -y opencv-python && \
    pip install --user --no-cache-dir opencv-python-headless && \
    python -c "import nltk; nltk.download('punkt_tab', quiet=True)" && \
    rm -rf /root/.cache/pip /tmp/pipecat

RUN find /root/.local -type f -name '*.pyc' -delete && \
    find /root/.local -type d -name '__pycache__' -prune -exec rm -rf {} + && \
    find /root/.local -type f -name '*.pyo' -delete && \
    find /root/.local -type d \( -name tests -o -name test -o -name examples \) -prune -exec rm -rf {} + && \
    find /root/.local -name '*.pyi' -delete

FROM node:22-slim AS ts-deps
WORKDIR /ts_validator
COPY api/mcp_server/ts_validator/package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM debian:trixie-slim AS ffmpeg-static
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates xz-utils \
    && curl -fsSL -o /tmp/ffmpeg.tar.xz https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz \
    && mkdir -p /tmp/ffmpeg \
    && tar -xJf /tmp/ffmpeg.tar.xz -C /tmp/ffmpeg --strip-components=1 \
    && mv /tmp/ffmpeg/ffmpeg /tmp/ffmpeg/ffprobe /usr/local/bin/ \
    && chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe

FROM python:3.12-slim AS runner

WORKDIR /app

COPY --from=ffmpeg-static /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=ffmpeg-static /usr/local/bin/ffprobe /usr/local/bin/ffprobe
COPY --from=node:22-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=builder /root/.local /root/.local
COPY --from=builder /root/nltk_data /root/nltk_data

ARG DATABASE_URL
ARG POSTGRES_URL
ARG DATABASE_PRIVATE_URL
ARG SUPABASE_DATABASE_URL
ARG SUPABASE_DB_URL
ARG SUPABASE_DB_PASSWORD
ARG SUPABASE_DATABASE_PASSWORD
ARG SUPABASE_PASSWORD
ARG POSTGRES_PASSWORD
ARG REDIS_URL
ARG REDIS_PRIVATE_URL
ARG COOLIFY_REDIS_URL
ARG UPSTASH_REDIS_URL
ARG SUPABASE_URL
ARG SUPABASE_S3_ENDPOINT
ARG SUPABASE_S3_REGION
ARG SUPABASE_S3_BUCKET
ARG SUPABASE_S3_ACCESS_KEY_ID
ARG SUPABASE_S3_SECRET_ACCESS_KEY
ARG AWS_ENDPOINT_URL
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG S3_REGION
ARG S3_BUCKET
ARG ENABLE_AWS_S3
ARG BACKEND_API_ENDPOINT
ARG UI_APP_URL
ARG OSS_JWT_SECRET
ARG AUTH_PROVIDER
ARG DEPLOYMENT_MODE

ENV PATH=/root/.local/bin:$PATH
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app
ENV LOG_TO_FILE=false
ENV DATABASE_URL=${DATABASE_URL}
ENV POSTGRES_URL=${POSTGRES_URL}
ENV DATABASE_PRIVATE_URL=${DATABASE_PRIVATE_URL}
ENV SUPABASE_DATABASE_URL=${SUPABASE_DATABASE_URL}
ENV SUPABASE_DB_URL=${SUPABASE_DB_URL}
ENV SUPABASE_DB_PASSWORD=${SUPABASE_DB_PASSWORD}
ENV SUPABASE_DATABASE_PASSWORD=${SUPABASE_DATABASE_PASSWORD}
ENV SUPABASE_PASSWORD=${SUPABASE_PASSWORD}
ENV POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
ENV REDIS_URL=${REDIS_URL}
ENV REDIS_PRIVATE_URL=${REDIS_PRIVATE_URL}
ENV COOLIFY_REDIS_URL=${COOLIFY_REDIS_URL}
ENV UPSTASH_REDIS_URL=${UPSTASH_REDIS_URL}
ENV SUPABASE_URL=${SUPABASE_URL}
ENV SUPABASE_S3_ENDPOINT=${SUPABASE_S3_ENDPOINT}
ENV SUPABASE_S3_REGION=${SUPABASE_S3_REGION}
ENV SUPABASE_S3_BUCKET=${SUPABASE_S3_BUCKET}
ENV SUPABASE_S3_ACCESS_KEY_ID=${SUPABASE_S3_ACCESS_KEY_ID}
ENV SUPABASE_S3_SECRET_ACCESS_KEY=${SUPABASE_S3_SECRET_ACCESS_KEY}
ENV AWS_ENDPOINT_URL=${AWS_ENDPOINT_URL}
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
ENV S3_REGION=${S3_REGION}
ENV S3_BUCKET=${S3_BUCKET}
ENV ENABLE_AWS_S3=${ENABLE_AWS_S3}
ENV BACKEND_API_ENDPOINT=${BACKEND_API_ENDPOINT}
ENV UI_APP_URL=${UI_APP_URL}
ENV OSS_JWT_SECRET=${OSS_JWT_SECRET}
ENV AUTH_PROVIDER=${AUTH_PROVIDER}
ENV DEPLOYMENT_MODE=${DEPLOYMENT_MODE}

COPY ./api ./api
COPY ./scripts/start_services_docker.sh ./scripts/start_services_docker.sh
COPY --from=ts-deps /ts_validator/node_modules ./api/mcp_server/ts_validator/node_modules
COPY ./docs ./docs

EXPOSE 8000

CMD ["./scripts/start_services_docker.sh"]

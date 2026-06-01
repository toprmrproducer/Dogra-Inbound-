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

ENV PATH=/root/.local/bin:$PATH
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app
ENV LOG_TO_FILE=false

COPY ./api ./api
COPY ./scripts/start_services_docker.sh ./scripts/start_services_docker.sh
COPY --from=ts-deps /ts_validator/node_modules ./api/mcp_server/ts_validator/node_modules
COPY ./docs ./docs

EXPOSE 8000

CMD ["./scripts/start_services_docker.sh"]

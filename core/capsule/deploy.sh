#!/usr/bin/env bash
set -euo pipefail

# ЛР1, рівень 3: розгортання капсули С.І.Д.
# Варіант 2: 2 % 4 = 2, суфікс charlie, порт 8082
SUFFIX="${SUFFIX:-charlie}"
NAME="${NAME:-capsule-$SUFFIX}"
HOST_PORT="${HOST_PORT:-8082}"
IMAGE="ubuntu:24.04"

# без Docker далі робити нічого
if ! docker info >/dev/null 2>&1; then
    echo "Docker недоступний" >&2
    exit 1
fi

# ідемпотентність: стару капсулу з таким іменем прибираємо
docker rm -f "$NAME" >/dev/null 2>&1 || true

# капсула у фоні, порт хоста -> 80 всередині
docker run -d --name "$NAME" -p "$HOST_PORT":80 "$IMAGE" sleep infinity >/dev/null

# утиліти ставимо без запитань
docker exec "$NAME" bash -c 'export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl git procps iproute2 >/dev/null'

# перевірка, що капсула справді працює
if [ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" != "true" ]; then
    echo "Капсула $NAME не піднялась" >&2
    exit 1
fi

echo "Капсула $NAME працює, порт $HOST_PORT -> 80"

# ---------- ЛР3: сліпий канал (рівні 2 і 3) ----------
# Мій варіант: N = 2, 2 % 4 = 2, обмін файлами через спільний том.
# Мережа і том це сутності демона, тому скрипт створює їх, тільки якщо їх ще нема.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NET="${NET:-mission-net}"
VOLUME="${VOLUME:-mission-logs}"
AGENT_IMAGE="${AGENT_IMAGE:-sid-capsule:slim}"
SECRETS="${SECRETS:-$REPO_ROOT/core/capsule/secrets.env}"

docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET" >/dev/null
docker volume inspect "$VOLUME" >/dev/null 2>&1 || docker volume create "$VOLUME" >/dev/null

# ключ береться тільки з файлу, якого нема в git (див. secrets.env.example)
if [ ! -f "$SECRETS" ]; then
    echo "Нема $SECRETS: скопіюй secrets.env.example і впиши ключ" >&2
    exit 1
fi

# agent це капсула з ЛР2 на debian:12-slim (у scratch-версії нема sh)
docker build -q -f "$REPO_ROOT/core/capsule/Dockerfile.slim" -t "$AGENT_IMAGE" "$REPO_ROOT" >/dev/null

docker rm -f agent storage >/dev/null 2>&1 || true

# storage і agent: одна мережа, один том, ключ через --env-file, а не -e
docker run -d --name storage --network "$NET" -v "$VOLUME":/data \
    --env-file "$SECRETS" alpine:3.20 sleep infinity >/dev/null
docker run -d --name agent --network "$NET" -v "$VOLUME":/data \
    --env-file "$SECRETS" "$AGENT_IMAGE" sleep infinity >/dev/null

echo "Сліпий канал готовий: мережа $NET, том $VOLUME, працюють agent і storage"

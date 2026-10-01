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

#!/usr/bin/env bash
# ЛР3, варіант 2 (2 % 4 = 2): обмін файлами через спільний том, без мережевого запиту.
#   bash core/capsule/channel.sh send [текст]  agent дописує рядок у /data/exfil.log
#   bash core/capsule/channel.sh read          storage читає файл і звіряє мітку ключа
# Формат рядка: 0xC1D::<текст>::<час UTC>::<мітка>
# Мітка це перші 12 символів sha256 від STORAGE_ACCESS_KEY. Сам ключ у файл не пишеться.
set -euo pipefail

case "${1:-}" in
  send)
    shift
    docker exec -e MSG="${*:-log-entry}" agent sh -c '
      tag=$(printf %s "$STORAGE_ACCESS_KEY" | sha256sum | cut -c1-12)
      echo "0xC1D::$MSG::$(date -u +%FT%TZ)::$tag" >> /data/exfil.log
      echo "agent записав рядок у /data/exfil.log"'
    ;;
  read)
    docker exec storage sh -c '
      tag=$(printf %s "$STORAGE_ACCESS_KEY" | sha256sum | cut -c1-12)
      while IFS= read -r line; do
        case "$line" in
          *"::$tag") echo "свій  $line" ;;
          *)         echo "чужий $line" ;;
        esac
      done < /data/exfil.log'
    ;;
  *)
    echo "Використання: $0 send [текст] | read" >&2
    exit 1
    ;;
esac

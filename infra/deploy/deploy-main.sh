#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/home/mdssoft/san7
RELEASE_DIR=/home/mdssoft/san7-release
REPOSITORY=https://github.com/Duyanh140900/san7-be.git
BRANCH=main
SRC_DIR="${1:-}"

if [ -z "$SRC_DIR" ]; then
  if [ ! -d "$RELEASE_DIR/.git" ]; then
    git clone --depth 1 --branch "$BRANCH" "$REPOSITORY" "$RELEASE_DIR"
  else
    git -C "$RELEASE_DIR" fetch --depth 1 origin "$BRANCH"
    git -C "$RELEASE_DIR" checkout --detach "origin/$BRANCH"
  fi
  SRC_DIR="$RELEASE_DIR"
fi

# Giu lai .env production tren server, dong bo code & infra tu main
rsync -a --delete \
  --exclude .env \
  --exclude .git \
  "$SRC_DIR/" "$APP_DIR/"

cd "$APP_DIR"
docker compose --profile tunnel up -d --build --wait

# Kiem tra health cua API qua localhost & Caddy
curl -fsS --retry 10 --retry-delay 3 --retry-all-errors http://127.0.0.1:3000/v1/health >/dev/null
curl -fsS --retry 5 --retry-delay 2 --retry-all-errors http://127.0.0.1/v1/health

docker compose --profile tunnel ps
docker image prune -f >/dev/null 2>&1 || true
#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR=/home/frappe/frappe-bench

if [ -d "$BENCH_DIR/apps/frappe" ]; then
  echo "Bench already exists, starting..."
  cd "$BENCH_DIR"
  bench start
  exit 0
fi

echo "Creating new bench..."
bench init --skip-redis-config-generation frappe-bench --version version-15

cd "$BENCH_DIR"

# Configure external services
bench set-mariadb-host "${MARIADB_HOST:-mariadb}"
bench set-redis-cache-host "${REDIS_URL:-redis:6379}"
bench set-redis-queue-host "${REDIS_URL:-redis:6379}"
bench set-redis-socketio-host "${REDIS_URL:-redis:6379}"

# Remove processes we run externally
sed -i '/redis/d' ./Procfile || true
sed -i '/watch/d' ./Procfile || true

# Fetch Insights app
bench get-app insights --branch "${INSIGHTS_BRANCH:-develop}"

SITE_NAME="${SITE_NAME:-insights.localhost}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"

bench new-site "$SITE_NAME" \
  --force \
  --mariadb-root-password "$MYSQL_ROOT_PASSWORD" \
  --admin-password "$ADMIN_PASSWORD" \
  --no-mariadb-socket

bench set-config -g server_script_enabled 1
bench --site "$SITE_NAME" install-app insights
bench --site "$SITE_NAME" set-config developer_mode 1
bench --site "$SITE_NAME" set-config mute_emails 1
bench --site "$SITE_NAME" clear-cache
bench use "$SITE_NAME"

# Start the dev server (exposes 8000)
bench start
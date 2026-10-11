#!/usr/bin/env bash
#
# Runs the whole stack the way production does: the SPA is built to static
# files, served by Rails from public/, with the API on the same origin.
#
# The difference from `npm run dev` matters. In development Vite proxies /api
# to Rails; here Rails serves both. Anything that only works through the proxy
# -- cookies, CSRF, redirects, the audio assets -- is exercised for real here.
#
# Usage:  ./scripts/preview-production.sh [port]

set -euo pipefail

PORT="${1:-4000}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"

echo "==> Building the client"
cd "$FRONTEND"
[ -d node_modules ] || npm ci
npm run build

echo
echo "==> Publishing the client into the Rails public directory"
rm -rf "$BACKEND/public/assets" "$BACKEND/public/sfx" "$BACKEND/public/index.html"
cp -r "$FRONTEND/dist/." "$BACKEND/public/"

echo
echo "==> Preparing the database"
cd "$BACKEND"
bin/rails db:prepare

echo
echo "==> Starting in production mode on port $PORT"
echo "    Open http://127.0.0.1:$PORT"
echo "    Stop with Ctrl-C."
echo

# Production refuses to boot without a real secret and forces HTTPS; both are
# relaxed here because this is a local rehearsal of the deployment, not a
# public deployment.
export RAILS_ENV=production
export SECRET_KEY_BASE="${SECRET_KEY_BASE:-$(bin/rails secret)}"
export RAILS_LOG_TO_STDOUT=1
export WEB_CLIENT_URL="http://127.0.0.1:$PORT"
export WELCOME_BONUS_MINOR="${WELCOME_BONUS_MINOR:-100000}"

# Production normally points DATABASE_URL at PostgreSQL. That gem is not in the
# bundle here, so the rehearsal runs on SQLite -- which still exercises
# everything the frontend depends on: same-origin cookies, CSRF, routing and
# static assets.
if [ -z "${DATABASE_URL:-}" ]; then
  export DATABASE_URL="sqlite3:$(pwd)/storage/production.sqlite3"
fi

# The client is served from the same origin, so cookies are first-party and
# there is no CORS involved -- exactly as in production.
bundle exec rails server -b 127.0.0.1 -p "$PORT"
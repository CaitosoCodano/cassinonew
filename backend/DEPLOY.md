# Production deployment notes
#
# The app is a single deployable: a Rails API that also serves the built SPA
# from public/. There is no separate frontend host to keep in sync, which
# removes the usual class of "works on the API, blank page on the web" bugs.

# --- 1. Build ---------------------------------------------------------------

cd ../frontend
npm ci
npm run build          # emits dist/ including public/sfx audio
cd ..

# Copy the built client into the Rails public directory. The API namespace
# wins in routes.rb, everything else falls through to index.html.
cp -r ../frontend/dist/* public/

# --- 2. Configure -----------------------------------------------------------
#
# Required environment variables (see .env.example for the full list):
#
#   SECRET_KEY_BASE        generate with: bin/rails secret
#   RAILS_MASTER_KEY      only if you use credentials
#   DATABASE_URL          e.g. postgres://user:pass@host:5432/luminara
#   REDIS_URL             required in production for the cache/queue
#   WEB_CLIENT_URL        the public origin, e.g. https://luminara.example
#   ADMIN_EMAIL           bootstrap administrator
#   ADMIN_PASSWORD        bootstrap administrator password
#   WELCOME_BONUS_MINOR   play-money granted to new accounts (0 disables)
#
# Generate secrets:
#   bin/rails secret
#   bin/rails credentials:edit

# --- 3. Migrate and seed ---------------------------------------------------

bin/rails db:prepare
bin/rails db:seed    # roles, feature flags, platform settings, admin user

# --- 4. Precompile ----------------------------------------------------------

bin/rails assets:precompile   # only if you add asset pipeline steps
# The SPA is prebuilt, so no webpacker run is required.

# --- 5. Serve ---------------------------------------------------------------
#
# Single process:
#   RAILS_ENV=production bin/rails server -b 0.0.0.0 -p 3000
#
# Behind a reverse proxy (nginx/Caddy) that terminates TLS and forwards to
# 127.0.0.1:3000. Set WEB_CLIENT_URL to the https origin so cookies and mail
# links are generated correctly.
#
# For process management use a unit file or a container entrypoint, not a
# foreground shell: the app must survive a reboot and restart on crash.

# --- 6. Verify --------------------------------------------------------------

curl -fsS https://your-host/up                      # => {"status":"ok"}
curl -fsS https://your-host/api/v1/config          # => brand config
# then, in a browser:
#   /register -> create an account -> land signed in with a wallet
#   /games    -> open a title -> spin -> watch the ledger move
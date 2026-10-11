# Production deployment notes
#
# The app is a single deployable: a Rails API that also serves the built SPA
# from public/. There is no separate frontend host to keep in sync, which
# removes the usual class of "works on the API, blank page on the web" bugs.
#
# That single origin is a requirement, not a convenience. Session cookies are
# SameSite=Lax and the CSRF token rides on them, so a client on one host calling
# an API on another is cross-site: browsers withhold the cookie and every
# request comes back unauthenticated. Do not split this into two hosts.

# --- 1. Render (recommended) -----------------------------------------------

# The blueprint at render.yaml describes the whole topology: one web service,
# one PostgreSQL database, and a pre-deploy step that migrates and seeds.

# In Render: New -> Blueprint -> point at this repository. Then set ADMIN_EMAIL
# and ADMIN_PASSWORD on the service and mark them secret. Nothing else needs to
# be filled in: Render exports RENDER_EXTERNAL_URL, which the application reads
# as the fallback for WEB_CLIENT_URL, so verification links in transactional
# email are correct without anyone copying a hostname by hand.

# The build compiles the client and copies it into backend/public/; Rails then
# serves those files itself. The pre-deploy step runs:

#     bin/rails db:prepare && bin/rails db:seed

# Skipping the seed would leave the deployment with no administrator and an
# empty lobby, since the game catalogue is seeded rather than hard-coded.

# --- 2. Configure, for any other host --------------------------------------

# Required environment variables (see .env.example for the full list):
#
#   SECRET_KEY_BASE        generate with: bin/rails secret
#   DATABASE_URL           e.g. postgres://user:pass@host:5432/luminara
#   WEB_CLIENT_URL         absolute origin WITH scheme, e.g.
#                          https://luminara.example
#   ADMIN_EMAIL            bootstrap administrator
#   ADMIN_PASSWORD         bootstrap administrator password, >= 12 characters
#   WELCOME_BONUS_MINOR    play-money granted to new accounts (0 disables)
#
# Optional:
#
#   REDIS_URL              shared rate-limit state for ActiveJob. Absent, the
#                          app uses an in-process store, which is correct for a
#                          single instance and wrong for several.
#   RAILS_MASTER_KEY       only if you start using encrypted credentials
#   SMTP_HOST et al.       without it, mail is written to tmp/mails
#
# WEB_CLIENT_URL must include the scheme. The mailers concatenate it to build a
# verification link, while Action Mailer needs the host on its own; both are
# derived from this one value rather than read from it separately.

# --- 3. Build ---------------------------------------------------------------

cd ../frontend
npm ci
npm run build          # emits dist/ including public/sfx audio
cd ..

# Copy the built client into the Rails public directory. The API namespace
# wins in routes.rb, everything else falls through to index.html.
cp -r ../frontend/dist/* public/

# --- 4. Migrate and seed ---------------------------------------------------

bin/rails db:prepare
bin/rails db:seed    # roles, feature flags, platform settings, game catalogue

# The seeds are idempotent: every record is looked up before it is written, so
# re-running them on each deploy is safe. The administrator password is the one
# exception -- it is applied when the account is created and left alone after,
# so a deploy cannot silently undo a password changed in the admin area. Set
# ADMIN_PASSWORD_FORCE=1 to reset one deliberately.

# --- 5. Precompile ---------------------------------------------------------

# No asset pipeline gem is used; the client is built by Vite and served as
# static files. Nothing to precompile.

# --- 6. Serve ---------------------------------------------------------------

# Single process:
#   RAILS_ENV=production bin/rails server -b 0.0.0.0 -p 3000
#
# Behind a reverse proxy (nginx/Caddy) that terminates TLS and forwards to
# 127.0.0.1:3000. Set WEB_CLIENT_URL to the https origin so cookies and mail
# links are generated correctly.
#
# For process management use a unit file or a container entrypoint, not a
# foreground shell: the app must survive a reboot and restart on crash.

# --- 7. Verify --------------------------------------------------------------

# /up is the health check Rails mounts for this purpose. It answers 200 with a
# small green page, which is what Render polls to decide an instance is ready.
curl -fsS -o /dev/null -w '%{http_code}\n' https://your-host/up   # => 200
curl -fsS https://your-host/api/v1/games                         # => the seeded catalogue
# then, in a browser:
#   /            -> the client loads and its hashed assets resolve
#   /register    -> create an account -> land signed in with a wallet
#   /games       -> open a title -> spin -> watch the ledger move
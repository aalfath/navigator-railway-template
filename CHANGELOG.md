# Changelog

Each entry is one version of this Railway template. Breaking changes come first.
Back up the Postgres database (`pg_dump`) before applying an update: Navigator
runs its database migrations automatically when it starts.

## v2.0.0 (2026-11-24)

- First release of the template: Navigator `v2.0.0` (upstream commit
  `c646445`), built on `node:22.23.5-alpine`, with Railway Postgres (pgvector).
- First boot creates the admin account from `ADMIN_EMAIL` and the generated
  `ADMIN_PASSWORD`, then keeps sign-up closed (`DISABLE_SIGN_UP=1`).
- Scheduled tasks run through the app's own cron endpoint every minute, so no
  Inngest account is needed.

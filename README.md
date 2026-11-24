[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/navigator?utm_medium=integration&utm_source=button&utm_campaign=navigator)

# Navigator on Railway

A one-click Railway template for [keinsaas Navigator](https://github.com/keinsaasforever/better-chatbot)
(Community Edition, formerly **better-chatbot**): a self-hosted AI chat and
agent workspace with MCP tool servers, workflows, projects and scheduled tasks.

- **App version:** `v2.0.0` (upstream commit `c646445`), MIT licence.
- **Built from:** this repo. Upstream publishes no container image, so the
  `Dockerfile` builds upstream's own Docker steps from the pinned release
  commit on `node:22.23.5-alpine@sha256:1314fb30…`.

## What it deploys

| Service | What it does |
| --- | --- |
| **Navigator** | The web app (Next.js) on port `$PORT`, health check `/ping`. Built from this repo. |
| **Postgres** | Railway's PostgreSQL with pgvector: accounts, chats, agents, workflows and document embeddings. On a volume. |

The app keeps no files of its own: everything lives in Postgres. File uploads
(attachments, avatars, generated images) need Supabase Storage and stay off
until you add it.

## Variables

| Variable | Default | |
| --- | --- | --- |
| `AI_GATEWAY_API_KEY` | *(you enter it)* | **Required.** A Vercel AI Gateway key from <https://vercel.com/ai-gateway>. One key serves every model in Navigator's menu (OpenAI, Anthropic, Google, Mistral, xAI, DeepSeek, …). |
| `ADMIN_EMAIL` | `admin@example.com` | Email of the admin account created on first boot. You sign in with it. |
| `ADMIN_PASSWORD` | generated | Password of that admin account. Find it in the Navigator service's Variables tab. |
| `BETTER_AUTH_SECRET` | generated | Session signing key. Also derives the key that encrypts saved connections, so don't change it later. |
| `SCHEDULED_TASK_SECRET` | generated | Protects the scheduled-task endpoint the start script calls every minute. |
| `POSTGRES_URL` | `${{Postgres.DATABASE_URL}}` | Private-network database connection. |
| `BETTER_AUTH_URL`, `NEXT_PUBLIC_BASE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL, used for sign-in cookies and links. Change both if you add a custom domain. |
| `DISABLE_SIGN_UP` | `1` | Keeps public sign-up closed. Add users from the admin area, or set `0` to open sign-up. |
| `PORT` | `3000` | Port the app listens on. |

Optional features are switched on by adding variables to the Navigator service
(see upstream's [self-hosting guide](https://github.com/keinsaasforever/better-chatbot/blob/v2.0.0/docs/self-hosting.md)):
`EXA_API_KEY` (web search), `COMPOSIO_API_KEY` (connected apps), `E2B_API_KEY`
(code sandboxes), `ASSEMBLYAI_API_KEY` (voice), `SUPABASE_URL` +
`SUPABASE_SERVICE_ROLE_KEY` + `NEXT_PUBLIC_SUPABASE_URL` (file uploads),
`REDIS_URL` (resumable chat streams), OAuth client IDs for GitHub, Google and
Microsoft sign-in.

## Memory

Navigator runs on Railway's Free plan limit of 0.5 GB RAM per service; the start
script sizes Node's heap from the container limit. Heavy use by several people
at once, or large PDF imports, is smoother with 1 GB.

## Updates

Railway tells everyone who deployed this template when this repo's `main`
branch changes. Read [`CHANGELOG.md`](CHANGELOG.md) first (breaking changes are
listed first), back up Postgres, then apply the update from the Railway
dashboard. Navigator runs its own database migrations at start-up.

## Licence

This wrapper is MIT. Navigator itself is MIT, © better-chatbot / keinsaas.

# Navigator (keinsaas Navigator Community Edition, formerly better-chatbot) for Railway.
# Upstream publishes no container image, so this builds upstream's own docker/Dockerfile
# steps from a pinned release commit on a pinned Node base image.
ARG NODE_IMAGE=node:22.23.5-alpine@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a

FROM ${NODE_IMAGE} AS builder
# Release v2.0.0 of https://github.com/keinsaasforever/better-chatbot
ARG NAVIGATOR_VERSION=v2.0.0
ARG NAVIGATOR_COMMIT=c646445baa420ec91e48a4a5860b4accf3b35236
# GitHub's archive of the release commit; its top folder is named after the commit.
ADD https://github.com/keinsaasforever/better-chatbot/archive/${NAVIGATOR_COMMIT}.tar.gz /tmp/src.tar.gz
WORKDIR /app
RUN tar -xzf /tmp/src.tar.gz -C /app --strip-components=1 \
 && test "$(tar -tzf /tmp/src.tar.gz | head -1)" = "better-chatbot-${NAVIGATOR_COMMIT}/" \
 && rm /tmp/src.tar.gz
ENV DOCKER_BUILD=1 \
    NEXT_STANDALONE_OUTPUT=true \
    NEXT_TELEMETRY_DISABLED=1 \
    TURBO_TELEMETRY_DISABLED=1 \
    DO_NOT_TRACK=1 \
    ELECTRON_SKIP_BINARY_DOWNLOAD=1 \
    CIRCLE_NODE_TOTAL=2 \
    NODE_OPTIONS=--max-old-space-size=3072
RUN corepack enable pnpm && pnpm install --frozen-lockfile
RUN pnpm build

FROM ${NODE_IMAGE} AS runner
ARG NAVIGATOR_VERSION=v2.0.0
LABEL org.opencontainers.image.source="https://github.com/aalfath/navigator-railway-template" \
      org.opencontainers.image.version="${NAVIGATOR_VERSION}"
RUN addgroup --system --gid 1001 nodejs \
 && adduser --system --uid 1001 nextjs
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder /app/apps/web/public ./apps/web/public
COPY --from=builder /app/apps/web/src/lib/db/migrations ./apps/web/src/lib/db/migrations
COPY --chmod=755 scripts/start.sh /usr/local/bin/navigator-start
# Helpers live next to server.js so they can load the app's bundled `postgres` driver.
COPY --chmod=755 scripts/bootstrap-admin.mjs scripts/db.mjs ./apps/web/railway/
# The `postgres` driver from upstream's lockfile (no dependencies of its own), for db.mjs.
COPY --from=builder /app/node_modules/.pnpm/postgres@3.4.7/node_modules/postgres ./apps/web/railway/node_modules/postgres
USER nextjs
EXPOSE 3000
CMD ["/usr/local/bin/navigator-start"]

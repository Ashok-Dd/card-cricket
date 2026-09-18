# Production image for the Card Cricket backend (NestJS + Prisma + Socket.IO).
# Build context is this directory (apps/backend) — on Render, set the
# service's "Root Directory" to apps/backend so it finds this file directly.
FROM node:22-alpine AS build
WORKDIR /app

COPY package.json package-lock.json .npmrc* ./
RUN npm ci

COPY prisma ./prisma
COPY prisma.config.ts ./
RUN npx prisma generate

COPY tsconfig*.json nest-cli.json ./
COPY src ./src
RUN npm run build

FROM node:22-alpine AS runtime
WORKDIR /app

# A full `npm ci` (not --omit=dev): the entrypoint runs `prisma migrate
# deploy` at container startup, and the `prisma` CLI + `dotenv` (used by
# prisma.config.ts / seed.ts) are devDependencies. Trading a larger image
# for not having to hand-pick which "dev" packages are actually runtime
# requirements. Critically, NODE_ENV=production must NOT be set yet here —
# `npm ci` silently skips devDependencies when it is, which meant no local
# `prisma` CLI existed at container startup and `npx prisma migrate deploy`
# silently fell back to downloading the latest prisma (8.0.0-rc.15, a
# pre-release incompatible with this project's pinned 7.10.0) instead of
# failing loudly — the entrypoint then hung/errored on that mismatched CLI
# and never reached `node dist/main.js`, so the container never bound to a
# port and Render's deploy timed out waiting for one.
COPY package.json package-lock.json .npmrc* ./
RUN npm ci

# Safe to set now — only affects the running Node process below, not the
# `npm ci` that already happened.
ENV NODE_ENV=production

COPY --from=build /app/dist ./dist
COPY prisma ./prisma
COPY prisma.config.ts ./
COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["./docker-entrypoint.sh"]

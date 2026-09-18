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
ENV NODE_ENV=production

# A full `npm ci` (not --omit=dev): the entrypoint runs `prisma migrate
# deploy` at container startup, and the `prisma` CLI + `dotenv` (used by
# prisma.config.ts / seed.ts) are devDependencies. Trading a larger image
# for not having to hand-pick which "dev" packages are actually runtime
# requirements.
COPY package.json package-lock.json .npmrc* ./
RUN npm ci

COPY --from=build /app/dist ./dist
COPY prisma ./prisma
COPY prisma.config.ts ./
COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["./docker-entrypoint.sh"]

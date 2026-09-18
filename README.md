# Card Cricket

Premium mobile-only, real-time multiplayer cricket card game — Top-Trumps-style statistic battles with collectible cricket player cards.

See `CLAUDE.md` for the condensed rules and architecture constraints, and `docs/` for the full design/rules references (`docs/SPEC.md` has the original long-form product spec).

## Repo layout

```
apps/
  mobile/     Flutter + Dart client
  backend/    NestJS + TypeScript server
docs/         Game rules, architecture, economy, card/visual design, roadmap
```

## Prerequisites

- Flutter 3.38+ / Dart 3.10+
- Node 22+, npm 10+
- Docker (for local Postgres + Redis)

## Getting started

### 1. Infra (Postgres + Redis)

```
docker compose up -d
```

### 2. Backend

```
cd apps/backend
cp .env.example .env   # already has working local-dev defaults matching docker-compose.yml
npm install
npx prisma generate
npm run start:dev
```

See `apps/backend/CLAUDE.md` for stack-specific gotchas (ESM imports, Prisma 7 driver adapters, the npm install quirk, etc.) before touching this project.

### 3. Mobile

```
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=WS_URL=http://10.0.2.2:3000
```

(`10.0.2.2` is the Android emulator's alias for the host machine; point it at your backend's actual address on a physical device.)

## Status

Foundation scaffold only — see `docs/ROADMAP.md` for the build order and current checklist.

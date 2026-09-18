#!/bin/sh
# Applies any pending migrations, then starts the server. `migrate deploy`
# (not `migrate dev`) is the correct production command — it only applies
# already-committed migration files, no shadow database or prompts.
set -e

npx prisma migrate deploy

# The curated player data only needs seeding once — db:seed's own
# alreadySeeded guard (prisma-seed/seed.ts) makes this safe to run on every
# boot without re-seeding or erroring on a populated database.
node dist/prisma-seed/seed.js || true

exec node dist/main.js

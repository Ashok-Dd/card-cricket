// Production seed data — real player careers extracted from Cricsheet
// ball-by-ball archives by apps/backend/scripts/extract-cricket-data.mjs
// into generated/cricket-data.json (committed; the raw ~1.2GB archives are
// not). See that script's header comment for the extraction methodology
// (career window, role classification, rating formula) and
// [[game-engine-design-decisions]] in project memory for why each of those
// was a deliberate call, not an arbitrary one.
//
// KNOWN GAP: the "odi" source folder turned out to be domestic/List-A
// one-day data (English county One-Day Cup, Ireland inter-provincial cup,
// ICC World Cricket League lower divisions, etc.), not international ODI
// matches — none of India/Australia/England/Pakistan/South Africa/etc.
// appear in it even once. The ODI card set is therefore skipped by this
// seed until the correct Cricsheet "ODI (male, international)" archive is
// supplied — seeding it from the wrong data would fill the set with
// obscure county cricketers instead of recognizable international players.
//
// Run via `npx prisma db seed` (wired up in prisma.config.ts, which builds
// the project then runs the compiled dist/prisma-seed/seed.js — Node's raw
// ESM loader can't resolve the generated Prisma client's `.js`-extension
// specifiers against its `.ts` sources without going through tsc first).
import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PrismaPg } from '@prisma/adapter-pg';
import {
  CardRarity,
  PlayerRole,
  PrismaClient,
  type Prisma,
} from '../generated/prisma/client.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

const BATTING_FIELDS = [
  'matchesPlayed',
  'inningsPlayed',
  'notOuts',
  'runs',
  'highestScore',
  'battingAverage',
  'ballsFaced',
  'strikeRate',
  'centuries',
  'halfCenturies',
];

const BOWLING_FIELDS = [
  'bowlingInnings',
  'overs',
  'runsConceded',
  'wickets',
  'bestBowling',
  'bowlingAverage',
  'economyRate',
  'bowlingStrikeRate',
  'dateOfBirth',
];

const STAT_SCHEMA = { batting: BATTING_FIELDS, bowling: BOWLING_FIELDS };

// The "odi" archive is real data (domestic List-A), just the wrong
// competition for an "ODI" card set — see the file-level comment. Skipped
// here, not deleted from the generator, so re-enabling it later is a
// one-line change once the correct source data is supplied.
const CARD_SETS = [
  { code: 'IPL', name: 'Indian Premier League' },
  { code: 'TEST', name: 'Test Cricket' },
  { code: 'T20', name: 'T20 International' },
] as const;

type CardSetCode = (typeof CARD_SETS)[number]['code'];

interface GeneratedCardStats {
  rarity: keyof typeof CardRarity;
  rating: number;
  matchesPlayed: number;
  inningsPlayed: number;
  notOuts: number;
  runs: number;
  highestScore: number;
  battingAverage: number | null;
  ballsFaced: number;
  strikeRate: number | null;
  centuries: number;
  halfCenturies: number;
  bowlingInnings: number;
  overs: number | null;
  runsConceded: number | null;
  wickets: number | null;
  bestBowling: string | null;
  bowlingAverage: number | null;
  economyRate: number | null;
  bowlingStrikeRate: number | null;
  catches: number;
  stumpings: number;
}

interface GeneratedPlayer {
  id: string;
  name: string;
  displayName: string;
  country: string;
  role: keyof typeof PlayerRole;
  team?: string;
  imageUrl?: string | null;
  cards: Partial<Record<CardSetCode | 'ODI', GeneratedCardStats>>;
}

interface GeneratedData {
  generatedAt: string;
  sourceWindow: string;
  poolSizePerFormat: number;
  players: GeneratedPlayer[];
}

function loadGeneratedData(): GeneratedData {
  const path = join(__dirname, 'generated', 'cricket-data.json');
  try {
    return JSON.parse(readFileSync(path, 'utf8')) as GeneratedData;
  } catch (error) {
    throw new Error(
      `Could not read ${path}. Run "node apps/backend/scripts/extract-cricket-data.mjs" ` +
        `(and optionally the image-fetch script) first to generate it.\n${(error as Error).message}`,
    );
  }
}

async function main() {
  const alreadySeeded = (await prisma.cardSet.count()) > 0;
  if (alreadySeeded) {
    console.log('Card sets already exist — skipping seed (seed is not meant to be re-run).');
    return;
  }

  const data = loadGeneratedData();
  console.log(
    `Loaded ${data.players.length} curated players (source window ${data.sourceWindow}, generated ${data.generatedAt})`,
  );

  const cardSetsByCode = new Map<CardSetCode, { id: string }>();
  for (const set of CARD_SETS) {
    const created = await prisma.cardSet.create({
      data: {
        code: set.code,
        name: set.name,
        statSchema: STAT_SCHEMA as unknown as Prisma.InputJsonValue,
      },
    });
    cardSetsByCode.set(set.code, created);
    console.log(`Created card set ${set.code}`);
  }

  // Bulk insert via client-generated UUIDs instead of one create() per row —
  // with ~1,500 players x ~2.5 cards each, sequential individual creates
  // meant several thousand round trips to a remote (Neon) database, which
  // measured out to well over an hour. Generating every id up front lets
  // players/statistics/cards each go in with a single createMany call.
  const playerRows: Prisma.PlayerCreateManyInput[] = [];
  const statsRows: Prisma.PlayerStatisticsCreateManyInput[] = [];
  const cardRows: Prisma.CardCreateManyInput[] = [];

  for (const playerSeed of data.players) {
    const cardEntries = Object.entries(playerSeed.cards).filter(
      (entry): entry is [CardSetCode, GeneratedCardStats] => entry[0] !== 'ODI',
    );
    if (cardEntries.length === 0) continue; // this player's only card(s) were in the skipped ODI set

    const playerId = randomUUID();
    playerRows.push({
      id: playerId,
      name: playerSeed.name,
      displayName: playerSeed.displayName,
      country: playerSeed.country,
      role: PlayerRole[playerSeed.role],
      team: playerSeed.team,
      imageUrl: playerSeed.imageUrl ?? null,
    });

    for (const [cardSetCode, cardData] of cardEntries) {
      const cardSet = cardSetsByCode.get(cardSetCode)!;
      const { rarity, rating, ...statsInput } = cardData;

      const statisticsId = randomUUID();
      statsRows.push({ id: statisticsId, ...statsInput, playerId, cardSetId: cardSet.id });
      cardRows.push({
        id: randomUUID(),
        playerId,
        cardSetId: cardSet.id,
        statisticsId,
        rarity: CardRarity[rarity],
        rating,
      });
    }
  }

  await prisma.player.createMany({ data: playerRows });
  console.log(`Inserted ${playerRows.length} players`);
  await prisma.playerStatistics.createMany({ data: statsRows });
  console.log(`Inserted ${statsRows.length} statistics profiles`);
  await prisma.card.createMany({ data: cardRows });
  console.log(`Inserted ${cardRows.length} cards`);

  console.log(`Done: ${playerRows.length} players, ${cardRows.length} cards.`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

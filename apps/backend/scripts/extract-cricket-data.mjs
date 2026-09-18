#!/usr/bin/env node
// One-time (re-runnable) extraction of real player statistics from the raw
// Cricsheet ball-by-ball match archives (repo-root ipl/, odi/, t20/, test/
// folders — gitignored, ~1.2GB, not shipped to production). Produces a
// compact curated JSON that `prisma-seed/seed.ts` reads to populate the DB —
// the heavy one-time parse never runs as part of `db:seed` itself.
//
// Usage: node apps/backend/scripts/extract-cricket-data.mjs
//
// Design notes (see docs/GAME_RULES.md / CLAUDE.md's "one player, many
// statistical profiles" rule): Cricsheet's `info.registry.people` maps a
// player's display name to a globally stable person ID, used here as the
// single join key across all 4 formats so e.g. Virat Kohli's IPL and ODI
// cards both point at the same underlying player, never a fork.
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '..', '..', '..');
const OUT_PATH = join(__dirname, '..', 'src', 'prisma-seed', 'generated', 'cricket-data.json');

const MIN_DATE = '1995-01-01';
const POOL_SIZE_PER_FORMAT = 500;

const FORMATS = [
  { code: 'IPL', name: 'Indian Premier League', folder: 'ipl', teamType: 'club' },
  { code: 'ODI', name: 'One Day International', folder: 'odi', teamType: 'international' },
  { code: 'T20', name: 'T20 International', folder: 't20', teamType: 'international' },
  { code: 'TEST', name: 'Test Cricket', folder: 'test', teamType: 'international' },
];

// Dismissal kinds not credited to the bowler (standard cricket scoring).
const NOT_BOWLER_WICKET = new Set([
  'run out',
  'retired hurt',
  'retired out',
  'retired not out',
  'timed out',
  'obstructing the field',
]);

function round(value, decimals) {
  if (value === null || value === undefined || !Number.isFinite(value)) return null;
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

/// Cricket over notation as a decimal (e.g. 122 overs + 1 ball -> 122.1),
/// matching the existing hand-written seed data's convention (never true
/// decimal overs) — see apps/backend/prisma/schema.prisma's `overs Float?`.
function ballsToOversNotation(legalBalls) {
  const whole = Math.floor(legalBalls / 6);
  const rem = legalBalls % 6;
  return round(whole + rem / 10, 1);
}

function newBattingAgg() {
  return {
    matchIds: new Set(),
    inningsBatted: 0,
    notOuts: 0,
    runs: 0,
    highestScore: 0,
    ballsFaced: 0,
    centuries: 0,
    halfCenturies: 0,
    inningsBowled: 0,
    ballsBowled: 0,
    runsConceded: 0,
    wickets: 0,
    bestBowling: null, // { wickets, runs }
    catches: 0,
    stumpings: 0,
  };
}

/// A "best bowling" figure only exists once a bowler has taken at least one
/// wicket somewhere in their career — matching standard cricket stat tables,
/// which show no figure at all (not "0/runs") for a wicketless bowler.
function isBetterBowling(candidate, current) {
  if (candidate.wickets === 0) return false;
  if (!current) return true;
  if (candidate.wickets !== current.wickets) return candidate.wickets > current.wickets;
  return candidate.runs < current.runs;
}

const registry = new Map(); // personId -> { names: Map<name,count>, countries: Map<name,count>, iplTeams: Map<name,count> }

function getRegistryEntry(id) {
  let entry = registry.get(id);
  if (!entry) {
    entry = { names: new Map(), countries: new Map(), iplTeams: new Map() };
    registry.set(id, entry);
  }
  return entry;
}

function bump(map, key, by = 1) {
  map.set(key, (map.get(key) ?? 0) + by);
}

function pickTopKey(map) {
  let bestKey = null;
  let bestCount = -1;
  for (const [key, count] of map) {
    if (count > bestCount) {
      bestKey = key;
      bestCount = count;
    }
  }
  return bestKey;
}

// format -> personId -> agg
const aggByFormat = new Map(FORMATS.map((f) => [f.code, new Map()]));

function getAgg(formatCode, personId) {
  const map = aggByFormat.get(formatCode);
  let agg = map.get(personId);
  if (!agg) {
    agg = newBattingAgg();
    map.set(personId, agg);
  }
  return agg;
}

let filesProcessed = 0;
let filesSkippedOldDate = 0;
let filesSkippedUnparseable = 0;

for (const format of FORMATS) {
  const dir = join(REPO_ROOT, format.folder);
  const files = readdirSync(dir).filter((f) => f.endsWith('.json'));
  console.log(`\n[${format.code}] ${files.length} match files`);

  for (const filename of files) {
    let data;
    try {
      data = JSON.parse(readFileSync(join(dir, filename), 'utf8'));
    } catch {
      filesSkippedUnparseable++;
      continue;
    }

    const info = data.info ?? {};
    const date = info.dates?.[0];
    if (!date || date < MIN_DATE) {
      filesSkippedOldDate++;
      continue;
    }

    const matchId = filename.replace(/\.json$/, '');
    const peopleRegistry = info.registry?.people ?? {};
    const resolve = (name) => peopleRegistry[name] ?? name;
    const teams = info.teams ?? [];
    const playersByTeam = info.players ?? {};

    // Squad membership -> matchesPlayed + global name/country/team registry.
    for (const teamName of teams) {
      const squad = playersByTeam[teamName] ?? [];
      for (const playerName of squad) {
        const id = resolve(playerName);
        const entry = getRegistryEntry(id);
        bump(entry.names, playerName);
        if (format.teamType === 'international') bump(entry.countries, teamName);
        if (format.code === 'IPL') bump(entry.iplTeams, teamName);

        getAgg(format.code, id).matchIds.add(matchId);
      }
    }

    for (const inning of data.innings ?? []) {
      if (inning.absent_hitters_wicket || inning.super_over) continue; // ignore super overs

      const battingLine = new Map(); // personId -> { runs, balls, dismissed }
      const bowlingLine = new Map(); // personId -> { balls, runs, wickets }
      const ensureBatting = (id) => {
        if (!battingLine.has(id)) battingLine.set(id, { runs: 0, balls: 0, dismissed: false });
        return battingLine.get(id);
      };
      const ensureBowling = (id) => {
        if (!bowlingLine.has(id)) bowlingLine.set(id, { balls: 0, runs: 0, wickets: 0 });
        return bowlingLine.get(id);
      };

      for (const over of inning.overs ?? []) {
        for (const delivery of over.deliveries ?? []) {
          const batterId = resolve(delivery.batter);
          const bowlerId = resolve(delivery.bowler);
          const nonStrikerId = delivery.non_striker ? resolve(delivery.non_striker) : null;
          const extras = delivery.extras ?? {};
          const isWide = 'wides' in extras;
          const isNoball = 'noballs' in extras;
          const isLegalBall = !isWide && !isNoball;
          const byesLegbyes = (extras.byes ?? 0) + (extras.legbyes ?? 0);

          const bLine = ensureBatting(batterId);
          bLine.runs += delivery.runs?.batter ?? 0;
          if (isLegalBall) bLine.balls += 1;
          if (nonStrikerId) ensureBatting(nonStrikerId); // credit "batted" even if they never face a ball

          const wLine = ensureBowling(bowlerId);
          if (isLegalBall) wLine.balls += 1;
          wLine.runs += (delivery.runs?.total ?? 0) - byesLegbyes;

          for (const wicket of delivery.wickets ?? []) {
            const dismissedId = resolve(wicket.player_out);
            ensureBatting(dismissedId).dismissed = true;
            if (!NOT_BOWLER_WICKET.has(wicket.kind)) wLine.wickets += 1;

            const fielderNames = (wicket.fielders ?? []).map((f) => f.name).filter(Boolean);
            if (wicket.kind === 'caught') {
              for (const fielderName of fielderNames) {
                const fielderId = resolve(fielderName);
                getAgg(format.code, fielderId).catches += 1;
              }
            } else if (wicket.kind === 'stumped') {
              for (const fielderName of fielderNames) {
                const fielderId = resolve(fielderName);
                getAgg(format.code, fielderId).stumpings += 1;
              }
            }
          }
        }
      }

      for (const [id, line] of battingLine) {
        const agg = getAgg(format.code, id);
        agg.inningsBatted += 1;
        agg.runs += line.runs;
        agg.ballsFaced += line.balls;
        if (line.runs > agg.highestScore) agg.highestScore = line.runs;
        if (line.runs >= 100) agg.centuries += 1;
        else if (line.runs >= 50) agg.halfCenturies += 1;
        if (!line.dismissed) agg.notOuts += 1;
      }

      for (const [id, line] of bowlingLine) {
        if (line.balls === 0 && line.wickets === 0) continue; // bowler never actually bowled a legal ball (rare data artifact)
        const agg = getAgg(format.code, id);
        agg.inningsBowled += 1;
        agg.ballsBowled += line.balls;
        agg.runsConceded += line.runs;
        agg.wickets += line.wickets;
        if (isBetterBowling(line, agg.bestBowling)) agg.bestBowling = { wickets: line.wickets, runs: line.runs };
      }
    }

    filesProcessed++;
  }
}

console.log(
  `\nProcessed ${filesProcessed} matches (skipped ${filesSkippedOldDate} pre-${MIN_DATE}, ${filesSkippedUnparseable} unparseable)`,
);

// ---------------------------------------------------------------------------
// Build the curated per-format player pool + card stats.
// ---------------------------------------------------------------------------

function buildCardStats(agg) {
  const battingAverage =
    agg.inningsBatted - agg.notOuts > 0 ? round(agg.runs / (agg.inningsBatted - agg.notOuts), 1) : null;
  const strikeRate = agg.ballsFaced > 0 ? round((agg.runs / agg.ballsFaced) * 100, 1) : null;
  const economyRate = agg.ballsBowled > 0 ? round((agg.runsConceded / agg.ballsBowled) * 6, 2) : null;
  const bowlingAverage = agg.wickets > 0 ? round(agg.runsConceded / agg.wickets, 1) : null;
  const bowlingStrikeRate = agg.wickets > 0 ? round(agg.ballsBowled / agg.wickets, 1) : null;

  return {
    matchesPlayed: agg.matchIds.size,
    inningsPlayed: agg.inningsBatted,
    notOuts: agg.notOuts,
    runs: agg.runs,
    highestScore: agg.highestScore,
    battingAverage,
    ballsFaced: agg.ballsFaced,
    strikeRate,
    centuries: agg.centuries,
    halfCenturies: agg.halfCenturies,
    bowlingInnings: agg.inningsBowled,
    overs: agg.ballsBowled > 0 ? ballsToOversNotation(agg.ballsBowled) : null,
    runsConceded: agg.inningsBowled > 0 ? agg.runsConceded : null,
    wickets: agg.inningsBowled > 0 ? agg.wickets : null,
    bestBowling: agg.bestBowling ? `${agg.bestBowling.wickets}/${agg.bestBowling.runs}` : null,
    bowlingAverage,
    economyRate,
    bowlingStrikeRate,
    catches: agg.catches,
    stumpings: agg.stumpings,
  };
}

/// Heuristic role classification (Cricsheet has no explicit position field).
/// Stumpings are only credited to wicketkeepers in the data, so any real
/// count of them is a strong signal. Otherwise the key signal is how OFTEN
/// a player bowls relative to how often they play — not just a raw ball
/// count, which trips on any career part-timer (e.g. a specialist batter
/// who occasionally rolls their arm over racks up a nonzero ball count over
/// hundreds of matches without ever being a genuine bowling threat).
function classifyRole(personId) {
  let matches = 0;
  let bowlingInnings = 0;
  let battingRuns = 0;
  let battingInnings = 0;
  let notOuts = 0;
  let stumpings = 0;
  for (const format of FORMATS) {
    const agg = aggByFormat.get(format.code).get(personId);
    if (!agg) continue;
    matches += agg.matchIds.size;
    bowlingInnings += agg.inningsBowled;
    battingRuns += agg.runs;
    battingInnings += agg.inningsBatted;
    notOuts += agg.notOuts;
    stumpings += agg.stumpings;
  }
  if (stumpings >= 3) return 'WICKET_KEEPER';

  const bowlingInvolvement = matches > 0 ? bowlingInnings / matches : 0;
  if (bowlingInvolvement < 0.5) return 'BATSMAN';

  // Bowls in most of their matches — genuine bowling contributor. Also a
  // meaningful batting contributor (decent average across a real sample of
  // dismissals) means all-rounder rather than a pure specialist bowler.
  const dismissals = battingInnings - notOuts;
  const battingAverage = dismissals > 0 ? battingRuns / dismissals : battingRuns;
  return battingAverage >= 20 ? 'ALL_ROUNDER' : 'BOWLER';
}

/// Rating (40-99) + rarity, computed per format from that format's own
/// player-pool distribution (a T20 strike rate and a Test strike rate mean
/// very different things, so each format is scored against its own peers,
/// not a single global scale). Role-aware: batting-primary roles are scored
/// on batting shape, bowlers on bowling shape, all-rounders/keepers blend.
function scorePlayers(formatCode, personIds) {
  const rows = personIds.map((id) => {
    const agg = aggByFormat.get(formatCode).get(id);
    const role = classifyRole(id);
    const battingAverage = agg.inningsBatted - agg.notOuts > 0 ? agg.runs / (agg.inningsBatted - agg.notOuts) : 0;
    const strikeRate = agg.ballsFaced > 0 ? (agg.runs / agg.ballsFaced) * 100 : 0;
    const bowlingEconomy = agg.ballsBowled > 0 ? (agg.runsConceded / agg.ballsBowled) * 6 : null;
    const bowlingAverage = agg.wickets > 0 ? agg.runsConceded / agg.wickets : null;
    return { id, role, battingAverage, strikeRate, bowlingEconomy, bowlingAverage };
  });

  function percentileRank(values, value, lowerIsBetter = false) {
    const sorted = [...values].sort((a, b) => a - b);
    let rank = sorted.filter((v) => v <= value).length / sorted.length;
    if (lowerIsBetter) rank = 1 - rank;
    return rank;
  }

  const battingAverages = rows.map((r) => r.battingAverage);
  const strikeRates = rows.map((r) => r.strikeRate);
  const bowlingAverages = rows.filter((r) => r.bowlingAverage !== null).map((r) => r.bowlingAverage);
  const bowlingEconomies = rows.filter((r) => r.bowlingEconomy !== null).map((r) => r.bowlingEconomy);

  const scores = new Map();
  for (const row of rows) {
    const battingScore =
      0.65 * percentileRank(battingAverages, row.battingAverage) +
      0.35 * percentileRank(strikeRates, row.strikeRate);
    const bowlingScore =
      row.bowlingAverage !== null && row.bowlingEconomy !== null
        ? 0.6 * percentileRank(bowlingAverages, row.bowlingAverage, true) +
          0.4 * percentileRank(bowlingEconomies, row.bowlingEconomy, true)
        : 0;

    let skill;
    if (row.role === 'BOWLER') skill = bowlingScore || battingScore;
    else if (row.role === 'ALL_ROUNDER') skill = bowlingScore > 0 ? (battingScore + bowlingScore) / 2 : battingScore;
    else skill = battingScore;

    const rating = Math.round(40 + skill * 59); // 40..99
    let rarity;
    if (rating >= 90) rarity = 'ICONIC';
    else if (rating >= 80) rarity = 'LEGENDARY';
    else if (rating >= 70) rarity = 'EPIC';
    else if (rating >= 58) rarity = 'RARE';
    else rarity = 'COMMON';

    scores.set(row.id, { rating, rarity });
  }
  return scores;
}

const players = new Map(); // personId -> { name, displayName, country, team, role, cards: {} }

for (const format of FORMATS) {
  const aggMap = aggByFormat.get(format.code);
  const ranked = [...aggMap.entries()]
    .filter(([, agg]) => agg.matchIds.size > 0)
    .sort((a, b) => b[1].matchIds.size - a[1].matchIds.size)
    .slice(0, POOL_SIZE_PER_FORMAT);

  const ratings = scorePlayers(
    format.code,
    ranked.map(([id]) => id),
  );

  console.log(`[${format.code}] pool: ${ranked.length} players (of ${aggMap.size} qualifying)`);

  for (const [id, agg] of ranked) {
    const regEntry = getRegistryEntry(id);
    const displayName = pickTopKey(regEntry.names) ?? id;
    const country = pickTopKey(regEntry.countries) ?? 'Unknown';
    const iplTeam = pickTopKey(regEntry.iplTeams);

    if (!players.has(id)) {
      players.set(id, {
        id,
        name: displayName,
        displayName,
        country,
        role: classifyRole(id),
        team: format.code === 'IPL' ? iplTeam : undefined,
        cards: {},
      });
    }
    const player = players.get(id);
    if (format.code === 'IPL' && iplTeam) player.team = iplTeam;

    const { rating, rarity } = ratings.get(id);
    player.cards[format.code] = { rarity, rating, ...buildCardStats(agg) };
  }
}

const output = {
  generatedAt: new Date().toISOString(),
  sourceWindow: `${MIN_DATE}..present`,
  poolSizePerFormat: POOL_SIZE_PER_FORMAT,
  players: [...players.values()],
};

writeFileSync(OUT_PATH, JSON.stringify(output));
console.log(`\nWrote ${output.players.length} unique curated players -> ${OUT_PATH}`);

// Stable content hash so downstream scripts (image fetch) can tell when the
// underlying data actually changed vs. re-running for no reason.
const hash = createHash('sha256').update(JSON.stringify(output.players)).digest('hex').slice(0, 12);
console.log(`Content hash: ${hash}`);

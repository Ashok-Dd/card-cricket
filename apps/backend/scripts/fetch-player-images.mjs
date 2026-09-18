#!/usr/bin/env node
// Fetches a free-licensed lead photo for each curated player from Wikipedia
// (matching by name), writing the result back into
// generated/cricket-data.json as `imageUrl`. Best-effort: a player with no
// confident match keeps `imageUrl: null` and the app's generated
// initials-portrait (PlayerAvatar) is used instead.
//
// Usage: node apps/backend/scripts/fetch-player-images.mjs [--force]
//
// Matching approach (see the failed first attempt this replaced): Cricsheet
// names are abbreviated ("JJ Bumrah", "SPD Smith"), which almost never
// matches a Wikipedia page title directly, and even a plain full-text
// search surfaces stats/list articles ("List of international cricket
// centuries by...") ahead of the actual biography. CirrusSearch's
// `intitle:` operator restricts results to pages whose TITLE contains the
// player's surname, which reliably surfaces the real bio page — then a
// cheap "does the extract mention cricket" check guards against a
// same-surnamed non-cricketer.
import { dirname, join } from 'node:path';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_PATH = join(__dirname, '..', 'src', 'prisma-seed', 'generated', 'cricket-data.json');
const FORCE = process.argv.includes('--force');
const CONCURRENCY = 3;
const REQUEST_DELAY_MS = 250; // per-worker pacing to stay well under Wikipedia's rate limit
const USER_AGENT = 'CardCricketApp/1.0 (https://github.com/; player-portrait-lookup)';

function surnameOf(name) {
  const parts = name.trim().split(/\s+/);
  return parts[parts.length - 1];
}

async function apiGet(url) {
  const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' } });
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch {
    return null; // rate-limited plaintext response or transient error — treated as "no result"
  }
}

async function searchTitles(query) {
  const url =
    'https://en.wikipedia.org/w/api.php?action=query&list=search&format=json&srnamespace=0&srlimit=6&srsearch=' +
    encodeURIComponent(query);
  const data = await apiGet(url);
  return (data?.query?.search ?? []).map((r) => r.title).filter((t) => !/^list of/i.test(t));
}

async function fetchSummary(title) {
  const url = `https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title)}`;
  const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT } });
  if (!res.ok) return null;
  try {
    return await res.json();
  } catch {
    return null;
  }
}

async function findCricketerImage(player) {
  const surname = surnameOf(player.displayName);
  const queries = [
    `intitle:${surname} cricketer ${player.country}`,
    `intitle:${surname} cricketer`,
  ];

  for (const query of queries) {
    const titles = await searchTitles(query);
    for (const title of titles.slice(0, 3)) {
      const summary = await fetchSummary(title);
      if (!summary || summary.type === 'disambiguation') continue;
      const text = `${summary.description ?? ''} ${summary.extract ?? ''}`.toLowerCase();
      if (!text.includes('cricket')) continue;
      const image = summary.thumbnail?.source ?? summary.originalimage?.source ?? null;
      if (image) return image;
    }
    if (titles.length > 0) break; // got real candidates but none had a usable photo — don't broaden further
  }
  return null;
}

async function mapWithConcurrency(items, limit, fn) {
  const results = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const i = next++;
      results[i] = await fn(items[i], i);
      await new Promise((resolve) => setTimeout(resolve, REQUEST_DELAY_MS));
    }
  }
  await Promise.all(Array.from({ length: limit }, worker));
  return results;
}

const data = JSON.parse(readFileSync(DATA_PATH, 'utf8'));
const players = data.players;
const pending = players.filter((p) => FORCE || !p.imageUrl);

console.log(`${players.length} curated players, ${pending.length} need an image lookup`);

let found = 0;
let checked = 0;

await mapWithConcurrency(pending, CONCURRENCY, async (player) => {
  let imageUrl = null;
  try {
    imageUrl = await findCricketerImage(player);
  } catch {
    imageUrl = null;
  }
  player.imageUrl = imageUrl;
  checked++;
  if (imageUrl) found++;
  if (checked % 50 === 0) {
    console.log(`...${checked}/${pending.length} checked, ${found} images found so far`);
    writeFileSync(DATA_PATH, JSON.stringify(data));
  }
});

writeFileSync(DATA_PATH, JSON.stringify(data));
console.log(`Done: ${found}/${pending.length} players got a real photo (rest fall back to the generated portrait).`);

#!/usr/bin/env node
// Fetches a free-licensed lead photo AND the real full name for each
// curated player from Wikipedia, writing `imageUrl` and `resolvedName`
// back into generated/cricket-data.json. Best-effort: a player with no
// confident match keeps both null — seed.ts falls back to the Cricsheet
// short name, and the app's generated initials-portrait covers the image.
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
// "does the extract mention cricket, AND does it not obviously belong to a
// different country" check guards against a same-surnamed wrong person
// (a real, confirmed problem with the first version of this script: a
// same-surname cricketer from a different country was sometimes the top
// hit, e.g. two different international "Khan"s or "Smith"s).
import { dirname, join } from 'node:path';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_PATH = join(__dirname, '..', 'src', 'prisma-seed', 'generated', 'cricket-data.json');
const FORCE = process.argv.includes('--force');
const CONCURRENCY = 2;
const REQUEST_DELAY_MS = 400; // per-worker pacing to stay well under Wikipedia's rate limit
const USER_AGENT = 'CardCricketApp/1.0 (https://github.com/; player-portrait-lookup)';

// Demonyms Wikipedia bios actually use ("an English cricketer", "a Sri
// Lankan cricketer") keyed by the country string this project's own data
// uses (Cricsheet team names) — used only to REJECT a candidate that
// clearly names a different nation, never to require a match (many bios
// phrase this differently, e.g. "cricketer who plays for..."), so this is
// a conservative false-positive guard, not a strict filter.
const DEMONYMS = {
  India: ['indian'],
  Australia: ['australian'],
  England: ['english', 'british'],
  Pakistan: ['pakistani'],
  'South Africa': ['south african'],
  'New Zealand': ['new zealand'],
  'Sri Lanka': ['sri lankan'],
  'West Indies': ['west indian', 'jamaican', 'barbadian', 'trinidadian', 'guyanese', 'antiguan'],
  Bangladesh: ['bangladeshi'],
  Afghanistan: ['afghan'],
  Ireland: ['irish'],
  Zimbabwe: ['zimbabwean'],
  Scotland: ['scottish'],
  Netherlands: ['dutch'],
  Namibia: ['namibian'],
  UAE: ['emirati'],
  Nepal: ['nepali', 'nepalese'],
  Canada: ['canadian'],
  USA: ['american'],
  Kenya: ['kenyan'],
  Uganda: ['ugandan'],
  Oman: ['omani'],
};
const ALL_DEMONYMS = Object.values(DEMONYMS).flat();

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

/// Strips a Wikipedia disambiguation suffix ("Steve Smith (cricketer)" ->
/// "Steve Smith") to get a clean display name.
function cleanTitle(title) {
  return title.replace(/\s*\([^)]*\)\s*$/, '').trim();
}

function looksLikeWrongCountry(text, expectedCountry) {
  const expected = DEMONYMS[expectedCountry];
  if (!expected) return false; // unknown country in our map — don't reject on this signal at all
  const mentionsExpected = expected.some((d) => text.includes(d));
  if (mentionsExpected) return false;
  const mentionsOther = ALL_DEMONYMS.some((d) => !expected.includes(d) && text.includes(d));
  return mentionsOther; // only reject when it clearly names a DIFFERENT nation
}

async function findCricketerMatch(player) {
  const surname = surnameOf(player.displayName);
  const queries = [`intitle:${surname} cricketer ${player.country}`, `intitle:${surname} cricketer`];

  for (const query of queries) {
    const titles = await searchTitles(query);
    for (const title of titles.slice(0, 4)) {
      const summary = await fetchSummary(title);
      if (!summary || summary.type === 'disambiguation') continue;
      const text = `${summary.description ?? ''} ${summary.extract ?? ''}`.toLowerCase();
      if (!text.includes('cricket')) continue;
      if (looksLikeWrongCountry(text, player.country)) continue;
      const image = summary.thumbnail?.source ?? summary.originalimage?.source ?? null;
      return { imageUrl: image ?? null, resolvedName: cleanTitle(summary.title ?? title) };
    }
    if (titles.length > 0) break; // got real candidates but none passed — don't broaden further
  }
  return { imageUrl: null, resolvedName: null };
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
const pending = players.filter((p) => FORCE || !p.imageUrl || !p.resolvedName);

console.log(`${players.length} curated players, ${pending.length} need a lookup`);

let foundImage = 0;
let foundName = 0;
let checked = 0;

await mapWithConcurrency(pending, CONCURRENCY, async (player) => {
  let result = { imageUrl: null, resolvedName: null };
  try {
    result = await findCricketerMatch(player);
  } catch {
    // best-effort — leave both null
  }
  player.imageUrl = result.imageUrl;
  player.resolvedName = result.resolvedName;
  checked++;
  if (result.imageUrl) foundImage++;
  if (result.resolvedName) foundName++;
  if (checked % 50 === 0) {
    console.log(`...${checked}/${pending.length} checked, ${foundImage} images / ${foundName} real names found so far`);
    writeFileSync(DATA_PATH, JSON.stringify(data));
  }
});

writeFileSync(DATA_PATH, JSON.stringify(data));
console.log(
  `Done: ${foundImage}/${pending.length} got a real photo, ${foundName}/${pending.length} got a resolved full name.`,
);

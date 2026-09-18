/// Cricket-correct comparison direction: for these three, a LOWER value is
/// the better bowling performance. Every other numeric stat is
/// higher-is-better. (Confirmed with the user — the spec text says "highest
/// wins" everywhere, but that's wrong for economy rate/bowling average/
/// bowling strike rate to any actual cricket fan.)
export const LOWER_IS_BETTER = new Set(['bowlingAverage', 'economyRate', 'bowlingStrikeRate']);

/// dateOfBirth is a date, not a game stat — comparing birthdates has no
/// cricket meaning, so it's never selectable. bestBowling ("4/25"-style
/// wickets/runs string) IS selectable — see parseBowlingFigure/
/// bowlingFigureScore below for how two bowling figures are actually
/// compared. (User-requested: every non-null stat on the card, including
/// bestBowling, should be pickable.)
export const NON_SELECTABLE_FIELDS = new Set(['dateOfBirth']);

const BOWLING_FIGURE_PATTERN = /^(\d+)\/(\d+)$/;

/// Parses a "wickets/runsConceded" bowling-figures string (e.g. "4/25").
/// Returns null for anything that isn't in that exact shape.
export function parseBowlingFigure(raw: unknown): { wickets: number; runs: number } | null {
  if (typeof raw !== 'string') return null;
  const match = BOWLING_FIGURE_PATTERN.exec(raw.trim());
  if (!match) return null;
  return { wickets: Number(match[1]), runs: Number(match[2]) };
}

/// A single sortable score for comparing bowling figures, matching the
/// standard cricket "best bowling" rule: more wickets always wins outright;
/// among equal wickets, fewer runs conceded (more economical) wins. Runs
/// conceded in a single innings is always far below 1000, so this encoding
/// is injective — two figures score equal only if they're actually equal,
/// which is a genuine tie.
export function bowlingFigureScore(figure: { wickets: number; runs: number }): number {
  return figure.wickets * 1000 - figure.runs;
}

export function isSelectableStatistic(
  field: string,
  statSchemaFields: string[],
  statistics: Record<string, unknown>,
): boolean {
  if (NON_SELECTABLE_FIELDS.has(field)) return false;
  if (!statSchemaFields.includes(field)) return false;
  const value = statistics[field];
  if (field === 'bestBowling') return parseBowlingFigure(value) !== null;
  return typeof value === 'number' && Number.isFinite(value);
}

/// The comparable numeric score AND the raw value to show the player for a
/// selected statistic's raw card value. For every plain-numeric stat these
/// are the same number; for bestBowling the display value is the original
/// "4/25" string while the comparison score is the encoded figure above.
export function extractComparisonValue(
  statistic: string,
  raw: unknown,
): { comparisonValue: number | null; displayValue: number | string | null } {
  if (statistic === 'bestBowling') {
    const figure = parseBowlingFigure(raw);
    return figure
      ? { comparisonValue: bowlingFigureScore(figure), displayValue: raw as string }
      : { comparisonValue: null, displayValue: null };
  }
  const value = typeof raw === 'number' ? raw : null;
  return { comparisonValue: value, displayValue: value };
}

/// Returns every playerId whose value is the winning extreme for this
/// statistic. Length > 1 means a tie. A player with a null/missing value
/// for this stat can never be part of the winning set.
export function determineWinners(
  values: Record<string, number | null>,
  statistic: string,
): string[] {
  const entries = Object.entries(values).filter(
    (entry): entry is [string, number] => entry[1] !== null,
  );
  if (entries.length === 0) return [];

  const lowerIsBetter = LOWER_IS_BETTER.has(statistic);
  const extreme = lowerIsBetter
    ? Math.min(...entries.map(([, value]) => value))
    : Math.max(...entries.map(([, value]) => value));

  return entries.filter(([, value]) => value === extreme).map(([userId]) => userId);
}

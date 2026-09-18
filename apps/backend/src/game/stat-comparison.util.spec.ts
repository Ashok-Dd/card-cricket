import { describe, expect, it } from 'vitest';
import {
  bowlingFigureScore,
  extractComparisonValue,
  isSelectableStatistic,
  parseBowlingFigure,
} from './stat-comparison.util.js';

describe('parseBowlingFigure', () => {
  it('parses a valid "wickets/runs" string', () => {
    expect(parseBowlingFigure('4/25')).toEqual({ wickets: 4, runs: 25 });
  });

  it('returns null for anything not in that exact shape', () => {
    expect(parseBowlingFigure(null)).toBeNull();
    expect(parseBowlingFigure(undefined)).toBeNull();
    expect(parseBowlingFigure(42)).toBeNull();
    expect(parseBowlingFigure('DNB')).toBeNull();
    expect(parseBowlingFigure('4-25')).toBeNull();
  });
});

describe('bowlingFigureScore', () => {
  it('ranks more wickets above fewer, regardless of runs conceded', () => {
    const fiveFor = bowlingFigureScore({ wickets: 5, runs: 80 });
    const fourFor = bowlingFigureScore({ wickets: 4, runs: 5 });
    expect(fiveFor).toBeGreaterThan(fourFor);
  });

  it('among equal wickets, ranks fewer runs conceded higher', () => {
    const economical = bowlingFigureScore({ wickets: 3, runs: 10 });
    const expensive = bowlingFigureScore({ wickets: 3, runs: 60 });
    expect(economical).toBeGreaterThan(expensive);
  });

  it('identical figures score identically (a genuine tie)', () => {
    expect(bowlingFigureScore({ wickets: 4, runs: 25 })).toBe(bowlingFigureScore({ wickets: 4, runs: 25 }));
  });
});

describe('isSelectableStatistic', () => {
  const schemaFields = ['runs', 'bestBowling', 'dateOfBirth'];

  it('bestBowling is selectable when it parses as a valid figure', () => {
    expect(isSelectableStatistic('bestBowling', schemaFields, { bestBowling: '4/25' })).toBe(true);
  });

  it('bestBowling is not selectable when null or unparseable', () => {
    expect(isSelectableStatistic('bestBowling', schemaFields, { bestBowling: null })).toBe(false);
    expect(isSelectableStatistic('bestBowling', schemaFields, { bestBowling: 'DNB' })).toBe(false);
  });

  it('dateOfBirth is never selectable, even with a value present', () => {
    expect(isSelectableStatistic('dateOfBirth', schemaFields, { dateOfBirth: '1990-01-01' })).toBe(false);
  });

  it('a plain numeric field is still selectable as before', () => {
    expect(isSelectableStatistic('runs', schemaFields, { runs: 100 })).toBe(true);
  });
});

describe('extractComparisonValue', () => {
  it('bestBowling: comparison score is the encoded figure, display value is the raw string', () => {
    const result = extractComparisonValue('bestBowling', '4/25');
    expect(result.displayValue).toBe('4/25');
    expect(result.comparisonValue).toBe(bowlingFigureScore({ wickets: 4, runs: 25 }));
  });

  it('a plain numeric stat: comparison and display values are the same number', () => {
    const result = extractComparisonValue('runs', 120);
    expect(result.comparisonValue).toBe(120);
    expect(result.displayValue).toBe(120);
  });

  it('an unparseable bestBowling value yields nulls, not a crash', () => {
    const result = extractComparisonValue('bestBowling', null);
    expect(result.comparisonValue).toBeNull();
    expect(result.displayValue).toBeNull();
  });
});

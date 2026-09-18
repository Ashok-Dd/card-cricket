# Card & Visual Design

This is the living design reference for the `CricketCard` widget and the game's overall visual language. Update this file every time the user supplies a new reference image or design correction — it is the source of truth for UI work, not the original wall-of-text spec.

## Reference image #1 (2026-09-18) — Ravichandran Ashwin sample card

The user supplied a sample card image and gave explicit corrections. **Current target layout:**

- Rounded card, gold/amber metallic border with a soft outer glow.
- **One single large player image only** — a full action/celebration shot filling the top ~55–60% of the card, set against a blurred stadium-crowd background.
  - ~~Do NOT include a second, small inset headshot photo~~ — user explicitly removed this. One image is enough.
  - ~~Do NOT include the top-left corner rank badge~~ (the playing-card suit style "Q ♦" corner flourish) — user explicitly removed this too. No corner rank/suit badge at all.
- Below the image: a country bar — small flag icon + country name (e.g. "INDIA") in caps, with the cricket board's crest/logo on the right side of the same bar.
- Below that: a bold, all-caps player name on a solid gold/amber banner (dark navy text), full width.
- Below the name: a role pill (e.g. "BOWLER") — small rounded dark-navy badge, centered, light-blue text, with decorative angled accent marks either side.
- Bottom ~40%: two-column stats block on a dark navy background:
  - Left column: **BATTING** (bat icon + header), rows: Matches Played, Innings Played, Not Outs, Runs, Highest Score, Average, Balls Faced, Strike Rate, 100's, 50's.
  - Right column: **BOWLING** (ball icon + header), rows: Innings P.I., Overs, Runs, Wickets, Best Bowling, Avg. Ball, Eco. Rate, Strike Rate, Date of Birth.
  - Each row: label left (white/light gray), value right (bold sky-blue), thin low-opacity divider line between rows, no vertical grid lines.
- Color palette for the card itself: dark navy/near-black base, gold/amber metallic border + name banner, sky-blue for stat values and section icons, white for labels, tricolor flag accent.

This is a **template**, not a fixed rule for every rarity/role — but unless a new reference image says otherwise, new cards should follow this structure: one hero image, flag+country+board bar, name banner, role pill, two-column stats block. Batting/Bowling column contents will vary per role (e.g. a specialist batsman's card may still show both blocks since the sample format shows it for a bowler too — reconfirm with the user if an all-rounder or wicketkeeper reference arrives).

## General visual direction (spec section 29–30)

Modern sports-esports + collectible-card aesthetic. Palette: deep black, deep navy, dark green, electric green, neon blue, gold, white, subtle gradients. Use glass effects, metallic reflections, soft glow, depth/shadow tastefully. Avoid: generic Material widgets, excessive blur/gradients, clutter, emoji-based UI, slow animations. Readability of stats always wins over decoration.

Rarity tiers (Common/Rare/Epic/Legendary/Iconic) should each get a distinct border/glow treatment once implemented, layered on top of this same base template.

## Animation notes (spec 31–34, condensed)

- Dealing: cards fly from deck to each player.
- Reveal: 3D-style flip.
- Stat selection: selected stat scales, glows, locks.
- Comparison: staged reveal of each player's value, then highlight the winner.
- Tie: explicit "TIE!" effect, then "CHOOSE ANOTHER STAT" prompt, with the same cards kept visibly on screen (never swap them out during a tie).
- Round win: modest glow/scale/particle burst on the winning card; collected cards visually fly to the winner's pile.
- Turn change: clear visual handoff to the new active player.
- Final victory: full celebration (confetti, particles, trophy, winner banner, stats recap) — reserved for match end only, not every round.

## Open items to confirm with future reference images

- All-rounder / wicketkeeper stat layout (extra rows like catches/stumpings).
- Rarity-tier visual differences (border/glow per tier).
- Card back design (for the dealing/shuffle animation).

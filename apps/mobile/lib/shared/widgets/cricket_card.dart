import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../models/card_model.dart';

/// The CricketCard template from docs/CARD_DESIGN.md, derived from the
/// user's reference image: one hero image (no corner rank badge, no second
/// inset photo), a flag/country/team bar, a gold name banner, a role pill,
/// and a two-column Batting/Bowling stats block.
///
/// No real card artwork exists yet, so the hero area is a layered
/// placeholder (stadium-light gradient + role silhouette + light sweep +
/// vignette) rather than a bare centered icon — swap in `card.imageUrl` via
/// CachedNetworkImage once artwork exists; nothing else about the layout
/// should need to change.
///
/// Field ordering below matches the current seed data's stat schema
/// (identical across all 4 card sets today). If a future card set ships a
/// different statSchema, this should read it instead of the static lists.
class CricketCard extends StatelessWidget {
  const CricketCard({required this.card, this.width = 260, super.key});

  final CardModel card;
  final double width;

  static const _battingFields = [
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

  static const _bowlingFields = [
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

  /// Public so the game screen can label its stat-selection buttons with
  /// the same friendly names the card itself shows.
  static const statLabels = _labels;

  static const _labels = {
    'matchesPlayed': 'Matches Played',
    'inningsPlayed': 'Innings Played',
    'notOuts': 'Not Outs',
    'runs': 'Runs',
    'highestScore': 'Highest Score',
    'battingAverage': 'Average',
    'ballsFaced': 'Balls Faced',
    'strikeRate': 'Strike Rate',
    'centuries': "100's",
    'halfCenturies': "50's",
    'bowlingInnings': 'Innings P.I.',
    'overs': 'Overs',
    'runsConceded': 'Runs',
    'wickets': 'Wickets',
    'bestBowling': 'Best Bowling',
    'bowlingAverage': 'Avg. Ball',
    'economyRate': 'Eco. Rate',
    'bowlingStrikeRate': 'Strike Rate',
    'dateOfBirth': 'Date of Birth',
  };

  @override
  Widget build(BuildContext context) {
    final rarityColor = AppColors.rarityColor(card.rarity);

    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: rarityColor.withValues(alpha: 0.45), blurRadius: 28, spreadRadius: 1),
          const BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 10)),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: AppColors.goldGradient,
        ),
        child: Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.black,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: ColoredBox(
              color: AppColors.navyDark,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _HeroImage(
                        width: width,
                        role: card.player.role,
                        rarityColor: rarityColor,
                        imageUrl: card.player.imageUrl ?? card.imageUrl,
                      ),
                      Positioned(
                        right: 10,
                        bottom: -18,
                        child: _RatingBadge(rating: card.rating, color: rarityColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _CountryBar(country: card.player.country, team: card.player.team),
                  _NameBanner(name: card.player.displayName),
                  _RolePill(role: card.player.role, color: rarityColor),
                  _StatsBlock(
                    card: card,
                    battingFields: _battingFields,
                    bowlingFields: _bowlingFields,
                    labels: _labels,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating, required this.color});
  final int rating;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [AppColors.navySurface, AppColors.navyDark]),
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10)],
      ),
      child: Text(
        '$rating',
        style: AppTextStyles.cardStatValue.copyWith(fontSize: 15, color: AppColors.textPrimary),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.width, required this.role, required this.rarityColor, this.imageUrl});
  final double width;
  final String role;
  final Color rarityColor;
  // The real player photo, when one was found (see
  // apps/backend/scripts/fetch-player-images.mjs) — falls back to the
  // layered placeholder below for the (still-common) case where no
  // confident match exists.
  final String? imageUrl;

  IconData get _icon {
    switch (role) {
      case 'BOWLER':
        return Icons.sports_baseball;
      case 'WICKET_KEEPER':
        return Icons.sports_handball;
      case 'ALL_ROUNDER':
        return Icons.workspace_premium;
      default:
        return Icons.sports_cricket;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Was 0.62 — a tall hero image made the whole card read as narrow and
    // elongated. Shrinking it (the card's width is unchanged) is what
    // actually widens the card's proportions, since the stats block below
    // stays a fixed height regardless of the image.
    final height = width * 0.42;
    final url = imageUrl;

    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && url.isNotEmpty) ...[
              // A neutral backdrop behind the photo — BoxFit.contain means
              // the photo doesn't necessarily fill the whole box (source
              // photos vary in aspect ratio), so this fills the letterbox
              // gaps instead of leaving them jarringly bare.
              _PlaceholderBackdrop(icon: _icon, height: height),
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ] else
              _PlaceholderBackdrop(icon: _icon, height: height),
            // Bottom vignette fading into the info panel — kept over a real
            // photo too, so the name banner below always stays legible.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.navyDark],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Icon(_icon, size: 18, color: rarityColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// The layered placeholder used both when a player has no real photo, and
/// as the loading/error state while one is being fetched — a stadium-light
/// gradient, a large soft-edged role silhouette, and a diagonal light sweep,
/// so it reads as a deliberate design rather than an empty box.
class _PlaceholderBackdrop extends StatelessWidget {
  const _PlaceholderBackdrop({required this.icon, required this.height});
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.4),
              radius: 1.1,
              colors: [AppColors.navyElevated, AppColors.navySurface, AppColors.navy],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Center(
          child: Icon(icon, size: height * 0.72, color: Colors.white.withValues(alpha: 0.07)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.08), Colors.transparent],
                stops: const [0.0, 0.5],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryBar extends StatelessWidget {
  const _CountryBar({required this.country, required this.team});
  final String country;
  final String? team;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.countryAccent(country);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: AppColors.navySurface,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          ),
          const SizedBox(width: 6),
          Text(country.toUpperCase(), style: AppTextStyles.overline.copyWith(color: AppColors.textPrimary)),
          const Spacer(),
          if (team != null)
            Flexible(
              child: Text(
                team!,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }
}

class _NameBanner extends StatelessWidget {
  const _NameBanner({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.goldGradient),
      padding: const EdgeInsets.symmetric(vertical: 9),
      alignment: Alignment.center,
      child: Text(
        name.toUpperCase(),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.cardName,
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role, required this.color});
  final String role;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navyDark,
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.navySurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(
          role.replaceAll('_', ' '),
          style: AppTextStyles.overline.copyWith(color: color),
        ),
      ),
    );
  }
}

class _StatsBlock extends StatelessWidget {
  const _StatsBlock({
    required this.card,
    required this.battingFields,
    required this.bowlingFields,
    required this.labels,
  });

  final CardModel card;
  final List<String> battingFields;
  final List<String> bowlingFields;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatColumn(
                title: 'BATTING',
                icon: Icons.sports_cricket,
                fields: battingFields,
                card: card,
                labels: labels,
              ),
            ),
            Container(width: 1, color: AppColors.glassBorder, margin: const EdgeInsets.symmetric(horizontal: 6)),
            Expanded(
              child: _StatColumn(
                title: 'BOWLING',
                icon: Icons.sports_baseball,
                fields: bowlingFields,
                card: card,
                labels: labels,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.title,
    required this.icon,
    required this.fields,
    required this.card,
    required this.labels,
  });

  final String title;
  final IconData icon;
  final List<String> fields;
  final CardModel card;
  final Map<String, String> labels;

  /// Never hides a row — a batsman's bowling numbers show as 0, not blank,
  /// so every card has the same, predictable shape (and height).
  String _valueFor(String field) {
    if (field == 'bestBowling') return card.statistics.bestBowling ?? '—';
    if (field == 'dateOfBirth') {
      final dob = card.statistics.dateOfBirth;
      if (dob == null) return '—';
      return '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}';
    }
    final value = card.statistics.numeric(field) ?? 0;
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(value.abs() < 10 ? 2 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final rows = fields.map((f) => MapEntry(f, _valueFor(f))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.skyBlue),
            const SizedBox(width: 4),
            Text(title, style: AppTextStyles.overline.copyWith(color: AppColors.skyBlue, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 4),
        for (final (index, entry) in rows.indexed)
          Container(
            color: index.isOdd ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    labels[entry.key] ?? entry.key,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardStatLabel.copyWith(fontSize: 10),
                  ),
                ),
                Text(entry.value, style: AppTextStyles.cardStatValue.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
      ],
    );
  }
}

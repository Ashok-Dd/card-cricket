import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

IconData roleIcon(String role) {
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

String _initialsOf(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

/// A player portrait — renders the real photo via `imageUrl` when one
/// exists (none of today's seed data has real artwork yet), and otherwise
/// falls back to a generated "trading card" portrait: a country-colored
/// gradient face with bold initials and a small role badge, standing in for
/// a photo rather than a bare icon in a circle.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    required this.role,
    this.name,
    this.country,
    this.imageUrl,
    this.size = 64,
    this.ringColor,
    super.key,
  });

  final String role;
  final String? name;
  final String? country;
  final String? imageUrl;
  final double size;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final ring = ringColor ?? AppColors.gold;
    final url = imageUrl;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2.5),
        boxShadow: [BoxShadow(color: ring.withValues(alpha: 0.45), blurRadius: 14, spreadRadius: 1)],
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, _) => _PortraitFace(role: role, name: name, country: country, size: size),
                errorWidget: (_, _, _) => _PortraitFace(role: role, name: name, country: country, size: size),
              )
            : _PortraitFace(role: role, name: name, country: country, size: size),
      ),
    );
  }
}

class _PortraitFace extends StatelessWidget {
  const _PortraitFace({required this.role, required this.name, required this.country, required this.size});

  final String role;
  final String? name;
  final String? country;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = country != null ? AppColors.countryAccent(country!) : AppColors.gold;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base.withValues(alpha: 0.9), AppColors.navyDark],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(roleIcon(role), size: size * 0.9, color: Colors.white.withValues(alpha: 0.10)),
          Text(
            _initialsOf(name),
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          Positioned(
            bottom: -1,
            right: -1,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navyDark,
                border: Border.all(color: base, width: 1.5),
              ),
              child: Icon(roleIcon(role), size: size * 0.19, color: base),
            ),
          ),
        ],
      ),
    );
  }
}

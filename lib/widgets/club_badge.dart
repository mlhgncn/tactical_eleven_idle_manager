import 'package:flutter/material.dart';

import '../theme/app_assets.dart';

enum ClubBadgeKind { home, away, neutral }

/// Renders one of the ringed badge-frame assets with the club's initials
/// overlaid, since clubs in this game don't have individual crest artwork.
class ClubBadge extends StatelessWidget {
  const ClubBadge({
    super.key,
    required this.clubName,
    this.kind = ClubBadgeKind.neutral,
    this.size = 36,
    this.avatarUrl,
  });

  final String clubName;
  final ClubBadgeKind kind;
  final double size;

  /// When the opposing club is controlled by a real user who has set a
  /// profile photo, show that instead of the club's initials - makes the
  /// "next match" card recognizably about a person, not just a bot club.
  final String? avatarUrl;

  String get _asset => switch (kind) {
        ClubBadgeKind.home => AppAssets.badgeHome,
        ClubBadgeKind.away => AppAssets.badgeAway,
        ClubBadgeKind.neutral => AppAssets.badgeNeutral,
      };

  // The badge artwork bakes placeholder initials ("BS"/"KF"/"FC") into the
  // ring - an opaque circle matching each ring's inner fill covers them
  // before the real initials are drawn, instead of layering text on top.
  Color get _fillColor => switch (kind) {
        ClubBadgeKind.home => const Color(0xFF1B2A4A),
        ClubBadgeKind.away => const Color(0xFF3D1420),
        ClubBadgeKind.neutral => const Color(0xFF2B3242),
      };

  String get _initials {
    final words = clubName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(_asset, width: size, height: size),
          if (hasAvatar)
            ClipOval(
              child: Image.network(
                avatarUrl!,
                width: size * 0.62,
                height: size * 0.62,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: size * 0.62,
                  height: size * 0.62,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _fillColor),
                ),
              ),
            )
          else ...[
            Container(
              width: size * 0.62,
              height: size * 0.62,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _fillColor),
            ),
            Text(
              _initials,
              style: TextStyle(
                fontSize: size * 0.32,
                fontWeight: FontWeight.bold,
                color: kind == ClubBadgeKind.neutral ? Colors.white70 : Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

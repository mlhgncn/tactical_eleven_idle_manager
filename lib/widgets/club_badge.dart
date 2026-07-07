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
  });

  final String clubName;
  final ClubBadgeKind kind;
  final double size;

  String get _asset => switch (kind) {
        ClubBadgeKind.home => AppAssets.badgeHome,
        ClubBadgeKind.away => AppAssets.badgeAway,
        ClubBadgeKind.neutral => AppAssets.badgeNeutral,
      };

  String get _initials {
    final words = clubName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(_asset, width: size, height: size),
          Text(
            _initials,
            style: TextStyle(
              fontSize: size * 0.32,
              fontWeight: FontWeight.bold,
              color: kind == ClubBadgeKind.neutral ? Colors.white70 : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

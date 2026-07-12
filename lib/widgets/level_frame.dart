import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../theme/app_theme.dart';

/// Şampiyonluk sayısından türeyen seviyeye göre isim/rozet çevresine
/// konan renkli çerçeve - lig puan durumu ve profil sayfasında kullanılır.
class LevelFrame extends StatelessWidget {
  const LevelFrame({super.key, required this.level, required this.child, this.padding = 3});

  final ProfileLevel level;
  final Widget child;
  final double padding;

  static Color solidColor(ProfileLevel level) => switch (level) {
        ProfileLevel.silver => const Color(0xFFC6CCD8),
        ProfileLevel.gold => AppColors.gold,
        ProfileLevel.diamond => const Color(0xFF3FA9F5),
        ProfileLevel.emerald => const Color(0xFF2ECC81),
        ProfileLevel.none => AppColors.cardBorder,
      };

  static String labelKey(ProfileLevel level) => switch (level) {
        ProfileLevel.silver => 'profile.levelSilver',
        ProfileLevel.gold => 'profile.levelGold',
        ProfileLevel.diamond => 'profile.levelDiamond',
        ProfileLevel.emerald => 'profile.levelEmerald',
        ProfileLevel.none => 'profile.levelNone',
      };

  @override
  Widget build(BuildContext context) {
    if (level == ProfileLevel.none) return child;

    final colors = [solidColor(level).withValues(alpha: 0.85), solidColor(level)];
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(color: solidColor(level).withValues(alpha: 0.45), blurRadius: 6, spreadRadius: 0.5),
        ],
      ),
      child: child,
    );
  }
}

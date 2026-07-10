import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/player_fm.dart';
import '../theme/app_assets.dart';
import '../theme/app_theme.dart';

/// Overlays player stats onto the gold player-card-frame asset. The frame's
/// artwork is a fixed 480x640 (0.75 aspect) layout, so child positions are
/// expressed as fractions of that canvas and scale with [width].
class PlayerCard extends StatelessWidget {
  const PlayerCard({super.key, required this.player, this.width = 260});

  final PlayerFM player;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width / 0.75;

    Widget at({
      required double left,
      required double top,
      required double w,
      required double h,
      required Widget child,
    }) {
      return Positioned(
        left: left * width,
        top: top * height,
        width: w * width,
        height: h * height,
        child: child,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Image.asset(AppAssets.playerCardFrame, width: width, height: height, fit: BoxFit.fill),
          // The frame artwork bakes a placeholder "87 / GÜÇ" badge into this
          // corner - an opaque gold badge covers it before redrawing the
          // real value, instead of layering text on top of the baked one.
          at(
            left: 0.065,
            top: 0.07,
            w: 0.31,
            h: 0.16,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.goldLight, AppColors.gold],
                ),
                borderRadius: BorderRadius.circular(width * 0.05),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${player.currentAbility}',
                    style: TextStyle(
                      color: AppColors.goldOnGoldText,
                      fontWeight: FontWeight.bold,
                      height: 1,
                      fontSize: width * 0.1,
                    ),
                  ),
                  Text(
                    'playerCard.power'.tr(),
                    style: TextStyle(
                      color: AppColors.goldOnGoldText,
                      fontWeight: FontWeight.bold,
                      height: 1,
                      fontSize: width * 0.04,
                    ),
                  ),
                ],
              ),
            ),
          ),
          at(
            left: 0.64,
            top: 0.095,
            w: 0.29,
            h: 0.09,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBottom,
                borderRadius: BorderRadius.circular(width * 0.045),
                border: Border.all(color: AppColors.blue, width: width * 0.006),
              ),
              alignment: Alignment.center,
              child: Text(
                player.position,
                style: TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: width * 0.055,
                ),
              ),
            ),
          ),
          // The frame artwork has "OYUNCU FOTO"/"OYUNCU ADI"/"HIZ ŞUT PAS"
          // baked in as placeholder labels, not a transparent slot - an
          // opaque cover behind each dynamic value hides the baked text
          // instead of layering on top of it.
          at(
            left: 0.24,
            top: 0.285,
            w: 0.52,
            h: 0.27,
            child: Center(
              child: Container(
                width: width * 0.5,
                height: width * 0.5,
                decoration: const BoxDecoration(color: Color(0xFF0F1728), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  player.name.isNotEmpty ? player.name.substring(0, 1).toUpperCase() : '?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.28,
                  ),
                ),
              ),
            ),
          ),
          at(
            left: 0.08,
            top: 0.645,
            w: 0.84,
            h: 0.08,
            child: Container(
              color: const Color(0xFF0F1728),
              alignment: Alignment.center,
              child: Text(
                player.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: width * 0.065,
                ),
              ),
            ),
          ),
          at(
            left: 0.07,
            top: 0.745,
            w: 0.28,
            h: 0.16,
            child: _statBox('playerCard.speed'.tr(), player.determination, width),
          ),
          at(
            left: 0.36,
            top: 0.745,
            w: 0.28,
            h: 0.16,
            child: _statBox('playerCard.shot'.tr(), player.finishing, width),
          ),
          at(
            left: 0.65,
            top: 0.745,
            w: 0.28,
            h: 0.16,
            child: _statBox('playerCard.pass'.tr(), player.passing, width),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, int value, double width) {
    return Container(
      color: const Color(0xFF0F1728),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: width * 0.06),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white70, fontSize: width * 0.032),
          ),
        ],
      ),
    );
  }
}

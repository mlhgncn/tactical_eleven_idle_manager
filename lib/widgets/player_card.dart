import 'package:flutter/material.dart';

import '../models/player_fm.dart';
import '../theme/app_assets.dart';

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
          at(
            left: 0.13,
            top: 0.09,
            w: 0.2,
            h: 0.13,
            child: Center(
              child: Text(
                '${player.currentAbility}',
                style: TextStyle(
                  color: const Color(0xFF241A05),
                  fontWeight: FontWeight.bold,
                  fontSize: width * 0.11,
                ),
              ),
            ),
          ),
          at(
            left: 0.69,
            top: 0.115,
            w: 0.19,
            h: 0.06,
            child: Center(
              child: Text(
                player.position,
                style: TextStyle(
                  color: const Color(0xFF7EC8F2),
                  fontWeight: FontWeight.bold,
                  fontSize: width * 0.055,
                ),
              ),
            ),
          ),
          at(
            left: 0.21,
            top: 0.255,
            w: 0.58,
            h: 0.335,
            child: Center(
              child: Text(
                player.name.isNotEmpty ? player.name.substring(0, 1).toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: width * 0.32,
                ),
              ),
            ),
          ),
          at(
            left: 0.05,
            top: 0.655,
            w: 0.9,
            h: 0.07,
            child: Center(
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
            left: 0.09,
            top: 0.755,
            w: 0.24,
            h: 0.14,
            child: _statBox('HIZ', player.determination, width),
          ),
          at(
            left: 0.38,
            top: 0.755,
            w: 0.24,
            h: 0.14,
            child: _statBox('ŞUT', player.finishing, width),
          ),
          at(
            left: 0.67,
            top: 0.755,
            w: 0.24,
            h: 0.14,
            child: _statBox('PAS', player.passing, width),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, int value, double width) {
    return Center(
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

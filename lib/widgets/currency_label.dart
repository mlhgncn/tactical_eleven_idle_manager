import 'package:flutter/material.dart';

import '../theme/app_assets.dart';

/// Coin-icon prefixed amount, for GP balances shown throughout the economy
/// screens instead of a bare "$value GP" string.
class CurrencyLabel extends StatelessWidget {
  const CurrencyLabel({
    super.key,
    required this.amount,
    this.style,
    this.iconSize = 18,
  });

  final int amount;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(AppAssets.coinGold, width: iconSize, height: iconSize),
        const SizedBox(width: 6),
        Text('$amount GP', style: style),
      ],
    );
  }
}

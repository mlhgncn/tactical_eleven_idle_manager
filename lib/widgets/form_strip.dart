import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_assets.dart';

enum FormResult { win, draw, loss }

/// A horizontal strip of W/D/L badges representing recent match results,
/// oldest first.
class FormStrip extends StatelessWidget {
  const FormStrip({super.key, required this.results, this.size = 26});

  final List<FormResult> results;
  final double size;

  String _assetFor(FormResult result) => switch (result) {
        FormResult.win => AppAssets.formWin,
        FormResult.draw => AppAssets.formDraw,
        FormResult.loss => AppAssets.formLoss,
      };

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Text('match.noFormYet'.tr(), style: Theme.of(context).textTheme.bodySmall);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final result in results) ...[
          Image.asset(_assetFor(result), width: size, height: size),
          const SizedBox(width: 6),
        ],
      ],
    );
  }
}

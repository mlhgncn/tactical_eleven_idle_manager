import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/player_fm.dart';

class FreeAgentCard extends StatelessWidget {
  final PlayerFM player;
  final Future<void> Function()? onSign;
  final VoidCallback? onTap;

  const FreeAgentCard({super.key, required this.player, this.onSign, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${player.name} (${player.position})', style: theme.textTheme.titleMedium),
                    ),
                    Chip(visualDensity: VisualDensity.compact, label: Text('transferMarket.freeAgentChip'.tr())),
                  ],
                ),
                const SizedBox(height: 8),
                Text('transferMarket.ageAbilityPotential'.tr(namedArgs: {
                  'age': player.age.toString(),
                  'ability': player.currentAbility.toString(),
                  'potential': player.potentialAbility.toString(),
                })),
                const SizedBox(height: 10),
                Text('transferMarket.signingCost'.tr(namedArgs: {'cost': player.signingCost.toString()}), style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onSign,
                  child: Text('transferMarket.signPlayer'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

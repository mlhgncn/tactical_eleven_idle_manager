import 'package:flutter/material.dart';
import '../models/player_fm.dart';

class FreeAgentCard extends StatelessWidget {
  final PlayerFM player;
  final Future<void> Function()? onSign;

  const FreeAgentCard({super.key, required this.player, this.onSign});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${player.name} (${player.position})', style: theme.textTheme.titleMedium),
              ),
              const Chip(visualDensity: VisualDensity.compact, label: Text('Serbest')),
            ],
          ),
          const SizedBox(height: 8),
          Text('Yaş: ${player.age} · Güç: ${player.currentAbility} · Potansiyel: ${player.potentialAbility}'),
          const SizedBox(height: 10),
          Text('İmza Bedeli: ${player.signingCost} GP', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onSign,
            child: const Text('Satın Al'),
          ),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/opponent_scout_report.dart';
import '../models/tactics.dart';
import '../theme/app_theme.dart';

/// Read-only preview of an upcoming opponent's squad + tactics, only
/// reachable once kickoff is within 15 minutes (enforced server-side by
/// the scout_opponent RPC). Deliberately simple - no formation pitch view
/// or full attribute breakdown, just the basics: who's available and what
/// system they're likely to play.
class OpponentScoutScreen extends StatelessWidget {
  const OpponentScoutScreen({super.key, required this.opponentName, required this.report});

  final String opponentName;
  final OpponentScoutReport report;

  @override
  Widget build(BuildContext context) {
    final tactics = report.tactics;
    final startingIds = tactics?.startingElevenIds?.toSet();
    final starters = startingIds == null
        ? const <ScoutedPlayer>[]
        : report.players.where((p) => startingIds.contains(p.id)).toList();
    final bench = startingIds == null
        ? report.players
        : report.players.where((p) => !startingIds.contains(p.id)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(opponentName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TacticsCard(tactics: tactics, tacticsHidden: report.tacticsHidden),
          const SizedBox(height: 16),
          if (starters.isNotEmpty) ...[
            Text('opponentScout.startingElevenTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final p in starters) _PlayerRow(player: p),
            const SizedBox(height: 16),
          ],
          Text(
            starters.isEmpty ? 'opponentScout.squadTitle'.tr() : 'opponentScout.benchTitle'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final p in bench) _PlayerRow(player: p),
        ],
      ),
    );
  }
}

class _TacticsCard extends StatelessWidget {
  const _TacticsCard({required this.tactics, this.tacticsHidden = false});

  final ScoutedTactics? tactics;
  final bool tacticsHidden;

  @override
  Widget build(BuildContext context) {
    if (tacticsHidden) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.visibility_off, color: AppColors.textMuted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('opponentScout.tacticsHidden'.tr(), style: const TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      );
    }
    if (tactics == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('opponentScout.noTactics'.tr(), style: const TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    final t = tactics!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('opponentScout.tacticsTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _stat('opponentScout.formationLabel'.tr(), t.formation.label),
                _stat('opponentScout.mentalityLabel'.tr(), _mentalityLabel(t.mentality)),
                _stat('opponentScout.pressLabel'.tr(), '${t.pressIntensity}'),
                _stat('opponentScout.tempoLabel'.tr(), '${t.tempo}'),
                _stat('opponentScout.defensiveLineLabel'.tr(), '${t.defensiveLine}'),
              ],
            ),
            if (t.offsideTrap || t.timeWasting) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (t.offsideTrap) Chip(label: Text('opponentScout.offsideTrapChip'.tr())),
                  if (t.timeWasting) Chip(label: Text('opponentScout.timeWastingChip'.tr())),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _mentalityLabel(Mentality m) => switch (m) {
        Mentality.defensive => 'tactics.mentalityDefensive'.tr(),
        Mentality.attacking => 'tactics.mentalityAttacking'.tr(),
        Mentality.balanced => 'tactics.balanced'.tr(),
      };

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player});

  final ScoutedPlayer player;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text(player.position)),
        title: Text(player.name),
        subtitle: Text('opponentScout.playerSubtitle'.tr(namedArgs: {
          'age': player.age.toString(),
          'ability': player.currentAbility.toString(),
        })),
        trailing: player.hasActiveInjury
            ? Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: AppColors.red.withValues(alpha: 0.15),
                label: Text(
                  player.isSuspended ? 'opponentScout.suspendedChip'.tr() : 'opponentScout.injuredChip'.tr(),
                  style: const TextStyle(fontSize: 11, color: AppColors.red),
                ),
              )
            : null,
      ),
    );
  }
}

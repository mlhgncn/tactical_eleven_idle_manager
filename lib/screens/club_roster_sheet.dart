import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/opponent_scout_report.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that lists a club's current squad, opened by tapping a
/// team row in the league table. Unlike the 15-minutes-to-kickoff scout
/// report, this has no timing/participant restriction - standings is a
/// page where everyone already sees everyone's results.
class ClubRosterSheet extends StatefulWidget {
  const ClubRosterSheet({super.key, required this.clubId, required this.clubName});

  final String clubId;
  final String clubName;

  @override
  State<ClubRosterSheet> createState() => _ClubRosterSheetState();
}

class _ClubRosterSheetState extends State<ClubRosterSheet> {
  late Future<OpponentScoutReport> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<GameProvider>().viewClubRoster(widget.clubId);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: FutureBuilder<OpponentScoutReport>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    snapshot.error.toString().replaceAll('Exception: ', ''),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                );
              }

              final report = snapshot.data!;
              final tactics = report.tactics;
              final startingIds = tactics?.startingElevenIds?.toSet();
              final starters = startingIds == null
                  ? const <ScoutedPlayer>[]
                  : report.players.where((p) => startingIds.contains(p.id)).toList();
              final bench = startingIds == null
                  ? report.players
                  : report.players.where((p) => !startingIds.contains(p.id)).toList();

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text(widget.clubName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('clubRoster.subtitle'.tr(namedArgs: {'count': report.players.length.toString()}),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                  const SizedBox(height: 16),
                  if (starters.isNotEmpty) ...[
                    Text('opponentScout.startingElevenTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final p in starters) _RosterPlayerRow(player: p),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    starters.isEmpty ? 'opponentScout.squadTitle'.tr() : 'opponentScout.benchTitle'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final p in bench) _RosterPlayerRow(player: p),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _RosterPlayerRow extends StatelessWidget {
  const _RosterPlayerRow({required this.player});

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

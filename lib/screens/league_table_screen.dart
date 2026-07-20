import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/club_badge.dart';
import '../widgets/level_frame.dart';
import 'club_roster_sheet.dart';

class LeagueTableScreen extends StatelessWidget {
  const LeagueTableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final activeClubId = provider.activeClub?.id;
    final seasonState = provider.seasonState;
    final standings = provider.standings;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final sortedStandings = List<Map<String, dynamic>>.from(standings)
      ..sort((a, b) {
        final pointsA = (a['points'] as num?)?.toInt() ?? 0;
        final pointsB = (b['points'] as num?)?.toInt() ?? 0;
        if (pointsB != pointsA) return pointsB.compareTo(pointsA);

        final goalDiffA = ((a['goals_for'] as num?)?.toInt() ?? 0) -
            ((a['goals_against'] as num?)?.toInt() ?? 0);
        final goalDiffB = ((b['goals_for'] as num?)?.toInt() ?? 0) -
            ((b['goals_against'] as num?)?.toInt() ?? 0);
        if (goalDiffB != goalDiffA) return goalDiffB.compareTo(goalDiffA);

        final goalsForA = (a['goals_for'] as num?)?.toInt() ?? 0;
        final goalsForB = (b['goals_for'] as num?)?.toInt() ?? 0;
        return goalsForB.compareTo(goalsForA);
      });

    return RefreshIndicator(
      onRefresh: () => context.read<GameProvider>().refreshGameState(),
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (seasonState != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seasonState['name']?.toString() ?? 'leagueTable.seasonFallback'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('leagueTable.weekLabel'.tr(namedArgs: {'week': (seasonState['current_week'] ?? 1).toString()})),
                  Text(
                    'leagueTable.statusLabel'.tr(namedArgs: {
                      'status': seasonState['is_completed'] == true
                          ? 'leagueTable.statusCompleted'.tr()
                          : 'leagueTable.statusOngoing'.tr(),
                    }),
                  ),
                  if ((seasonState['league'] as Map<String, dynamic>?)?['invitation_code'] != null) ...[
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final code = (seasonState['league'] as Map<String, dynamic>)['invitation_code'].toString();
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code));
                          AppSnackBar.showSuccess(context, 'leagueTable.inviteCodeCopied'.tr());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('leagueTable.inviteCodeLabel'.tr(), style: const TextStyle(color: AppColors.textMuted)),
                              Text(
                                code,
                                style: const TextStyle(
                                  color: AppColors.goldLight,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy, size: 16, color: AppColors.goldLight),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (sortedStandings.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('leagueTable.noStandingsYet'.tr()),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(builder: (context, constraints) {
              return Column(
                children: [
                  Container(
                    color: AppColors.cardBottom,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        const SizedBox(width: 22, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                        Expanded(child: Text('leagueTable.teamLabel'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                        _headerCell('leagueTable.columnPlayed'.tr()),
                        _headerCell('leagueTable.columnWon'.tr()),
                        _headerCell('leagueTable.columnDraw'.tr()),
                        _headerCell('leagueTable.columnLost'.tr()),
                        _headerCell('leagueTable.columnGoalDiff'.tr()),
                        _headerCell('leagueTable.columnPoints'.tr(), bold: true),
                      ],
                    ),
                  ),
                  for (final entry in sortedStandings.asMap().entries)
                    _StandingRow(
                      position: entry.key + 1,
                      row: entry.value,
                      isActiveClub: (entry.value['club'] as Map?)?['id'] == activeClubId,
                    ),
                ],
              );
            }),
          ),
      ],
      ),
    );
  }

  static Widget _headerCell(String label, {bool bold = false}) {
    return SizedBox(
      width: 30,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: bold ? AppColors.goldLight : AppColors.textMuted),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.position, required this.row, required this.isActiveClub});

  final int position;
  final Map<String, dynamic> row;
  final bool isActiveClub;

  @override
  Widget build(BuildContext context) {
    final club = row['club'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final clubId = club['id'] as String?;
    final played = (row['played'] as num?)?.toInt() ?? 0;
    final wins = (row['wins'] as num?)?.toInt() ?? 0;
    final draws = (row['draws'] as num?)?.toInt() ?? 0;
    final losses = (row['losses'] as num?)?.toInt() ?? 0;
    final goalsFor = (row['goals_for'] as num?)?.toInt() ?? 0;
    final goalsAgainst = (row['goals_against'] as num?)?.toInt() ?? 0;
    final goalDifference = goalsFor - goalsAgainst;
    final points = (row['points'] as num?)?.toInt() ?? 0;
    final username = club['username']?.toString();
    final clubName = club['name']?.toString() ?? 'leagueTable.teamLabel'.tr();
    final ownerLevel = Profile.levelForTitles((club['owner_league_titles'] as num?)?.toInt() ?? 0);

    return InkWell(
      onTap: clubId == null
          ? null
          : () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ClubRosterSheet(clubId: clubId, clubName: clubName),
              ),
      child: Container(
        color: isActiveClub ? AppColors.gold.withValues(alpha: 0.14) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$position',
                style: TextStyle(fontSize: 12.5, color: isActiveClub ? AppColors.goldLight : AppColors.textPrimary, fontWeight: isActiveClub ? FontWeight.bold : FontWeight.normal),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  LevelFrame(
                    level: ownerLevel,
                    padding: 2,
                    child: ClubBadge(
                      clubName: clubName,
                      kind: isActiveClub ? ClubBadgeKind.home : ClubBadgeKind.neutral,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          clubName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isActiveClub ? AppColors.goldLight : AppColors.textPrimary,
                            fontWeight: isActiveClub ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (username != null)
                          Text(
                            '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 30, child: Text('$played', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
            SizedBox(width: 30, child: Text('$wins', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
            SizedBox(width: 30, child: Text('$draws', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
            SizedBox(width: 30, child: Text('$losses', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
            SizedBox(width: 30, child: Text('$goalDifference', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
            SizedBox(
              width: 30,
              child: Text(
                '$points',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isActiveClub ? AppColors.goldLight : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

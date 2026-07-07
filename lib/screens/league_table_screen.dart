import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../widgets/club_badge.dart';

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

    return ListView(
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
                    seasonState['name']?.toString() ?? 'Sezon',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Hafta: ${seasonState['current_week'] ?? 1}'),
                  Text(
                    'Durum: ${seasonState['is_completed'] == true ? 'Tamamlandı' : 'Devam ediyor'}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (sortedStandings.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Henüz puan durumu yok.'),
            ),
          )
        else
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.resolveWith(
                  (states) => Colors.grey.shade100,
                ),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Takım')),
                  DataColumn(label: Text('G')),
                  DataColumn(label: Text('B')),
                  DataColumn(label: Text('M')),
                  DataColumn(label: Text('A+')),
                  DataColumn(label: Text('A-')),
                  DataColumn(label: Text('Av.')),
                  DataColumn(label: Text('P')),
                ],
                rows: sortedStandings.asMap().entries.map((entry) {
                  final position = entry.key + 1;
                  final row = entry.value;
                  final club = row['club'] as Map<String, dynamic>? ??
                      <String, dynamic>{};
                  final teamId = club['id'] as String?;
                  final isActiveClub = teamId != null && teamId == activeClubId;
                  final wins = (row['wins'] as num?)?.toInt() ?? 0;
                  final draws = (row['draws'] as num?)?.toInt() ?? 0;
                  final losses = (row['losses'] as num?)?.toInt() ?? 0;
                  final goalsFor = (row['goals_for'] as num?)?.toInt() ?? 0;
                  final goalsAgainst = (row['goals_against'] as num?)?.toInt() ?? 0;
                  final goalDifference = goalsFor - goalsAgainst;
                  final points = (row['points'] as num?)?.toInt() ?? 0;

                  return DataRow(
                    color: WidgetStateProperty.resolveWith(
                      (states) => isActiveClub ? Colors.yellow.shade100 : null,
                    ),
                    cells: [
                      DataCell(Text('$position')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClubBadge(
                              clubName: club['name']?.toString() ?? 'Takım',
                              kind: isActiveClub ? ClubBadgeKind.home : ClubBadgeKind.neutral,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(club['name']?.toString() ?? 'Takım'),
                          ],
                        ),
                      ),
                      DataCell(Text('$wins')),
                      DataCell(Text('$draws')),
                      DataCell(Text('$losses')),
                      DataCell(Text('$goalsFor')),
                      DataCell(Text('$goalsAgainst')),
                      DataCell(Text('$goalDifference')),
                      DataCell(Text('$points')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

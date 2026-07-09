import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/club_badge.dart';
import '../widgets/themed_button.dart';
import 'match_summary_screen.dart';

class MatchScheduleScreen extends StatelessWidget {
  const MatchScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final fixtures = provider.fixtures;
    final results = provider.results;

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              labelColor: AppColors.goldLight,
              unselectedLabelColor: AppColors.navInactive,
              indicatorColor: AppColors.goldLight,
              tabs: const [
                Tab(text: 'Takvim'),
                Tab(text: 'Sonuçlar'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: () => context.read<GameProvider>().refreshGameState(),
                  child: fixtures.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(child: Text('Henüz fikstür oluşturulmadı.')),
                          ),
                        ],
                      )
                    : Builder(builder: (context) {
                        final nextUpcomingIndex = fixtures.indexWhere((fixture) => fixture.status == 'Yaklaşan');
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: fixtures.length,
                          itemBuilder: (context, index) {
                            final fixture = fixtures[index];
                            final isPlayed = fixture.status == 'Tamamlandı';
                            final homeAwayLabel = fixture.isHome ? 'Ev' : 'Deplasman';
                            final homeAwayColor = fixture.isHome ? AppColors.green : AppColors.blue;
                            final dateLabel = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR')
                                .format(fixture.kickoff.toLocal());
                            final isNextUpcoming = index == nextUpcomingIndex && !isPlayed;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: ClubBadge(
                                        clubName: fixture.opponentName,
                                        kind: fixture.isHome ? ClubBadgeKind.away : ClubBadgeKind.home,
                                        size: 36,
                                      ),
                                      title: Text(fixture.opponentName,
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: homeAwayColor.withValues(alpha: 0.16),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: homeAwayColor.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  homeAwayLabel,
                                                  style: TextStyle(
                                                    color: homeAwayColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text('Hafta ${fixture.week}', style: const TextStyle(color: AppColors.textMuted)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            isPlayed
                                                ? '${fixture.homeScore} - ${fixture.awayScore}'
                                                : dateLabel,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: isPlayed ? AppColors.textPrimary : AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Chip(
                                        label: Text(fixture.status),
                                        backgroundColor: fixture.status == 'Tamamlandı'
                                            ? AppColors.green.withValues(alpha: 0.14)
                                            : AppColors.gold.withValues(alpha: 0.14),
                                        labelStyle: TextStyle(
                                          color: fixture.status == 'Tamamlandı' ? AppColors.green : AppColors.goldLight,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                        side: BorderSide.none,
                                      ),
                                    ),
                                    if (isNextUpcoming) ...[
                                      const SizedBox(height: 12),
                                      GoldButton(
                                        height: 44,
                                        isLoading: provider.isBusy,
                                        onPressed: provider.isBusy
                                            ? null
                                            : () async {
                                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                                final navigator = Navigator.of(context);
                                                try {
                                                  final result = await provider.playNextFixture();
                                                  navigator.push(
                                                    MaterialPageRoute(
                                                      builder: (_) => MatchSummaryScreen(result: result),
                                                    ),
                                                  );
                                                } catch (error) {
                                                  scaffoldMessenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Maç oynatılırken hata oluştu: ${error.toString()}',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                        label: 'Maçı Oyna',
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }),
                ),
                RefreshIndicator(
                  onRefresh: () => context.read<GameProvider>().refreshGameState(),
                  child: results.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(child: Text('Geçmiş maç yok.')),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final result = results[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                'Sonuç: ${result.homeScore} - ${result.awayScore}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text('Toplam şutlar: ${result.homeShots} - ${result.awayShots}'),
                                  Text('Possession: ${result.homePossession}%'),
                                  const SizedBox(height: 10),
                                  const Text('Özet:',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

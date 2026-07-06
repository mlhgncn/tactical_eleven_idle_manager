import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
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
              tabs: const [
                Tab(text: 'Takvim'),
                Tab(text: 'Sonuçlar'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                fixtures.isEmpty
                    ? const Center(child: Text('Henüz fikstür oluşturulmadı.'))
                    : Builder(builder: (context) {
                        final nextUpcomingIndex = fixtures.indexWhere((fixture) => fixture.status == 'Yaklaşan');
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: fixtures.length,
                          itemBuilder: (context, index) {
                            final fixture = fixtures[index];
                            final isPlayed = fixture.status == 'Tamamlandı';
                            final homeAwayLabel = fixture.isHome ? 'Ev' : 'Deplasman';
                            final homeAwayColor = fixture.isHome ? Colors.green : Colors.blue;
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
                                                  color: homeAwayColor.withValues(alpha: 0.18),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: homeAwayColor.withValues(alpha: 0.5)),
                                                ),
                                                child: Text(
                                                  homeAwayLabel,
                                                  style: TextStyle(
                                                    color: fixture.isHome ? Colors.green.shade800 : Colors.blue.shade800,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text('Hafta ${fixture.week}'),
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
                                              color: isPlayed ? Colors.black87 : Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Chip(
                                        label: Text(fixture.status),
                                        backgroundColor: fixture.status == 'Tamamlandı'
                                            ? Colors.green.shade50
                                            : Colors.orange.shade50,
                                      ),
                                    ),
                                    if (isNextUpcoming) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 40,
                                        child: ElevatedButton(
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
                                          child: provider.isBusy
                                              ? const SizedBox(
                                                  height: 16,
                                                  width: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Text('Maçı Oyna'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }),
                results.isEmpty
                    ? const Center(child: Text('Geçmiş maç yok.'))
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
                                  const SizedBox(height: 6),
                                  Text(result.summary ?? result.commentary.join('\n')),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MatchSummaryScreen(result: result),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

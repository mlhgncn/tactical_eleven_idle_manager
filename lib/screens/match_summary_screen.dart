import 'package:flutter/material.dart';

import '../models/match_event.dart';
import '../models/match_result.dart';

class MatchSummaryScreen extends StatelessWidget {
  final MatchResult result;

  const MatchSummaryScreen({super.key, required this.result});

  String _humanizeEventType(String eventType) {
    switch (eventType) {
      case 'goal':
        return 'Gol';
      case 'penalty':
        return 'Penaltı';
      case 'yellow_card':
        return 'Sarı Kart';
      case 'red_card':
        return 'Kırmızı Kart';
      case 'injury':
        return 'Sakatlık';
      case 'substitution':
        return 'Oyuncu Değişikliği';
      default:
        return eventType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = List<MatchEvent>.from(result.events)
      ..sort((a, b) => a.minute.compareTo(b.minute));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maç Özeti'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skor: ${result.homeScore} - ${result.awayScore}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.summary ?? 'Maç özeti mevcut değil.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const Text(
              'Olay Akışı',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        result.commentary.isNotEmpty
                            ? result.commentary.join('\n')
                            : 'Olay akışı bulunamadı.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${event.minute}. dk - ${_humanizeEventType(event.eventType)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(event.description),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

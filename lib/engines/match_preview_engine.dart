import 'dart:math';

import '../models/player_fm.dart';

/// UI preview/sandbox only. Not used for authoritative production results.
/// This is a client-side placeholder for visual previews and tests.
class MatchPreviewEngine {
  final Random _random = Random();

  Map<String, dynamic> previewMatch({
    required String homeTeamName,
    required String awayTeamName,
    required List<PlayerFM> homeSquad,
    required List<PlayerFM> awaySquad,
    required String homeMentality,
  }) {
    final homeScore = _random.nextInt(4);
    final awayScore = _random.nextInt(3);

    return {
      'home_score': homeScore,
      'away_score': awayScore,
      'home_shots': homeScore + _random.nextInt(8),
      'away_shots': awayScore + _random.nextInt(6),
      'home_xg': 1.45,
      'away_xg': 0.92,
      'home_possession': 52,
      'commentary': <String>[
        'Preview: $homeTeamName vs $awayTeamName',
        'Bu sadece arayüz önizlemesidir; gerçek sonuç sunucu tarafında hesaplanır.',
      ],
      'preview_only': true,
    };
  }
}

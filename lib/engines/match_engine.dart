import 'dart:math';
import '../models/player_fm.dart';

class AdvancedMatchEngine {
  final Random _random = Random();

  Map<String, dynamic> simulateMatch({required String homeTeamName, required String awayTeamName, required List<PlayerFM> homeSquad, required List<PlayerFM> awaySquad, required String homeMentality}) {
    int homeScore = _random.nextInt(4);
    int awayScore = _random.nextInt(3);
    return {
      'home_score': homeScore,
      'away_score': awayScore,
      'home_shots': homeScore + _random.nextInt(8),
      'away_shots': awayScore + _random.nextInt(6),
      'home_xg': 1.45,
      'away_xg': 0.92,
      'home_possession': 52,
      'commentary': []
    };
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tactical_eleven_idle_manager/engines/match_preview_engine.dart';
import 'package:tactical_eleven_idle_manager/models/player_fm.dart';

void main() {
  test('preview engine produces a non-negative match result for UI previews', () {
    final previewEngine = MatchPreviewEngine();
    final result = previewEngine.previewMatch(
      homeTeamName: 'Home Club',
      awayTeamName: 'Away Club',
      homeSquad: [
        PlayerFM(
          id: 'p1',
          clubId: 'club-a',
          name: 'Home Player',
          position: 'ST',
          age: 25,
          currentAbility: 80,
          potentialAbility: 85,
          morale: 75,
          fitness: 90,
          finishing: 78,
          passing: 74,
          tackling: 60,
          composure: 70,
          determination: 72,
          consistency: 76,
          injuryProneness: 4,
        ),
      ],
      awaySquad: [
        PlayerFM(
          id: 'p2',
          clubId: 'club-b',
          name: 'Away Player',
          position: 'ST',
          age: 27,
          currentAbility: 78,
          potentialAbility: 82,
          morale: 74,
          fitness: 88,
          finishing: 74,
          passing: 72,
          tackling: 62,
          composure: 68,
          determination: 70,
          consistency: 74,
          injuryProneness: 5,
        ),
      ],
      homeMentality: 'balanced',
    );

    expect(result['home_score'], isA<int>());
    expect(result['away_score'], isA<int>());
    expect(result['home_score'], greaterThanOrEqualTo(0));
    expect(result['away_score'], greaterThanOrEqualTo(0));
    expect(result['commentary'], isA<List>());
  });
}

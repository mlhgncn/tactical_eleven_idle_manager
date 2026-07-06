import 'match_event.dart';

class MatchResult {
  final String homeTeamId;
  final String awayTeamId;
  final int homeScore;
  final int awayScore;
  final int homeShots;
  final int awayShots;
  final double homeXg;
  final double awayXg;
  final int homePossession;
  final String? summary;
  final List<String> commentary;
  final List<MatchEvent> events;

  MatchResult({
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeScore,
    required this.awayScore,
    required this.homeShots,
    required this.awayShots,
    required this.homeXg,
    required this.awayXg,
    required this.homePossession,
    this.summary,
    required this.commentary,
    required this.events,
  });

  factory MatchResult.fromMap(Map<String, dynamic> map) {
    final commentaryRaw = map['commentary'];
    final commentary = <String>[];
    if (commentaryRaw is List) {
      commentary.addAll(commentaryRaw
          .where((item) => item != null)
          .map((item) => item.toString())
          .where((line) => line.isNotEmpty));
    }

    final eventsRaw = map['events'];
    final events = <MatchEvent>[];
    if (eventsRaw is List) {
      for (final rawEvent in eventsRaw) {
        if (rawEvent is Map<String, dynamic>) {
          events.add(MatchEvent.fromMap(rawEvent));
        } else if (rawEvent is Map) {
          events.add(MatchEvent.fromMap(Map<String, dynamic>.from(rawEvent)));
        }
      }
    }

    return MatchResult(
      homeTeamId: map['home_team_id'] as String? ?? '',
      awayTeamId: map['away_team_id'] as String? ?? '',
      homeScore: (map['home_score'] as num?)?.toInt() ?? 0,
      awayScore: (map['away_score'] as num?)?.toInt() ?? 0,
      homeShots: (map['home_shots'] as num?)?.toInt() ?? 0,
      awayShots: (map['away_shots'] as num?)?.toInt() ?? 0,
      homeXg: (map['home_xg'] as num?)?.toDouble() ?? 0.0,
      awayXg: (map['away_xg'] as num?)?.toDouble() ?? 0.0,
      homePossession: (map['home_possession'] as num?)?.toInt() ?? 50,
      summary: map['summary'] as String?,
      commentary: commentary,
      events: events,
    );
  }
}

class CupMatch {
  final String matchId;
  final String cupTournamentId;
  final int cupRound;
  final String homeClubId;
  final String homeClubName;
  final String awayClubId;
  final String awayClubName;
  final int? homeScore;
  final int? awayScore;
  final bool isPlayed;
  final DateTime matchDate;
  final String tournamentStatus;

  const CupMatch({
    required this.matchId,
    required this.cupTournamentId,
    required this.cupRound,
    required this.homeClubId,
    required this.homeClubName,
    required this.awayClubId,
    required this.awayClubName,
    this.homeScore,
    this.awayScore,
    required this.isPlayed,
    required this.matchDate,
    required this.tournamentStatus,
  });

  static const _roundNames = {1: 'Round of 16', 2: 'Quarter-Final', 3: 'Semi-Final', 4: 'Final'};
  String get roundName => _roundNames[cupRound] ?? 'Round $cupRound';

  factory CupMatch.fromMap(Map<String, dynamic> map) {
    return CupMatch(
      matchId: map['match_id'] as String,
      cupTournamentId: map['cup_tournament_id'] as String,
      cupRound: (map['cup_round'] as num).toInt(),
      homeClubId: map['home_club_id'] as String,
      homeClubName: map['home_club_name'] as String? ?? '?',
      awayClubId: map['away_club_id'] as String,
      awayClubName: map['away_club_name'] as String? ?? '?',
      homeScore: (map['home_score'] as num?)?.toInt(),
      awayScore: (map['away_score'] as num?)?.toInt(),
      isPlayed: map['is_played'] as bool? ?? false,
      matchDate: DateTime.parse(map['match_date'] as String),
      tournamentStatus: map['tournament_status'] as String? ?? 'active',
    );
  }
}

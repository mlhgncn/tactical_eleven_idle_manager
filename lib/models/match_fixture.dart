class MatchFixture {
  final String id;
  final String opponentName;
  final String? opponentUsername;
  final String? opponentClubId;
  final DateTime kickoff;
  final bool isHome;
  final String status;
  final int homeScore;
  final int awayScore;
  final int week;

  MatchFixture({
    required this.id,
    required this.opponentName,
    this.opponentUsername,
    this.opponentClubId,
    required this.kickoff,
    required this.isHome,
    required this.status,
    required this.homeScore,
    required this.awayScore,
    this.week = 1,
  });
}

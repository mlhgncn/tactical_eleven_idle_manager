class MatchFixture {
  final String id;
  final String opponentName;
  final DateTime kickoff;
  final bool isHome;
  final String status;
  final int homeScore;
  final int awayScore;

  MatchFixture({
    required this.id,
    required this.opponentName,
    required this.kickoff,
    required this.isHome,
    required this.status,
    required this.homeScore,
    required this.awayScore,
  });
}

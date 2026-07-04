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
  final List<String> commentary;

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
    required this.commentary,
  });
}

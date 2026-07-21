class LeaderboardEntry {
  final int rank;
  final String id;
  final String username;
  final String? avatarUrl;
  final int leagueTitles;
  final int totalWins;
  final int bestWinStreak;
  final bool hasUnbeatenTitle;

  const LeaderboardEntry({
    required this.rank,
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.leagueTitles,
    required this.totalWins,
    required this.bestWinStreak,
    required this.hasUnbeatenTitle,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      rank: (map['rank'] as num).toInt(),
      id: map['id'] as String,
      username: map['username'] as String? ?? '?',
      avatarUrl: map['avatar_url'] as String?,
      leagueTitles: (map['league_titles'] as num?)?.toInt() ?? 0,
      totalWins: (map['total_wins'] as num?)?.toInt() ?? 0,
      bestWinStreak: (map['best_win_streak'] as num?)?.toInt() ?? 0,
      hasUnbeatenTitle: map['has_unbeaten_title'] as bool? ?? false,
    );
  }
}

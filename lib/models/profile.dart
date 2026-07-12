enum ProfileLevel { none, silver, gold, diamond, emerald }

class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? email;
  final String language;
  final String? fcmToken;
  final String? username;
  final int leagueTitles;
  final int diamonds;
  final int totalWins;
  final int currentWinStreak;
  final int bestWinStreak;
  final bool achievement100WinsClaimed;
  final bool achievementWinStreak10Claimed;
  final bool hasUnbeatenTitle;
  final bool achievementUnbeatenChampionClaimed;
  final bool achievementMaxFacilityClaimed;
  final int longestLoginStreak;
  final bool achievement45DayStreakClaimed;
  final int dailyStreakDay;
  final DateTime? lastDailyClaimDate;
  final bool socialInstagramFollowed;
  final bool socialXFollowed;
  final bool socialTiktokFollowed;
  final bool socialEngagementClaimed;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.email,
    required this.language,
    this.fcmToken,
    this.username,
    this.leagueTitles = 0,
    this.diamonds = 0,
    this.totalWins = 0,
    this.currentWinStreak = 0,
    this.bestWinStreak = 0,
    this.achievement100WinsClaimed = false,
    this.achievementWinStreak10Claimed = false,
    this.hasUnbeatenTitle = false,
    this.achievementUnbeatenChampionClaimed = false,
    this.achievementMaxFacilityClaimed = false,
    this.longestLoginStreak = 0,
    this.achievement45DayStreakClaimed = false,
    this.dailyStreakDay = 0,
    this.lastDailyClaimDate,
    this.socialInstagramFollowed = false,
    this.socialXFollowed = false,
    this.socialTiktokFollowed = false,
    this.socialEngagementClaimed = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// [leagueTitles]'a göre hesaplanan seviye - static olarak da kullanılabilir
  /// (lig puan durumunda başka kullanıcıların çerçevesini göstermek için).
  static ProfileLevel levelForTitles(int titles) {
    if (titles >= 50) return ProfileLevel.emerald;
    if (titles >= 20) return ProfileLevel.diamond;
    if (titles >= 10) return ProfileLevel.gold;
    if (titles >= 5) return ProfileLevel.silver;
    return ProfileLevel.none;
  }

  ProfileLevel get level => levelForTitles(leagueTitles);

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      email: map['email'] as String?,
      language: map['language'] as String? ?? 'tr',
      fcmToken: map['fcm_token'] as String?,
      username: map['username'] as String?,
      leagueTitles: (map['league_titles'] as num?)?.toInt() ?? 0,
      diamonds: (map['diamonds'] as num?)?.toInt() ?? 0,
      totalWins: (map['total_wins'] as num?)?.toInt() ?? 0,
      currentWinStreak: (map['current_win_streak'] as num?)?.toInt() ?? 0,
      bestWinStreak: (map['best_win_streak'] as num?)?.toInt() ?? 0,
      achievement100WinsClaimed: (map['achievement_100_wins_claimed'] as bool?) ?? false,
      achievementWinStreak10Claimed: (map['achievement_win_streak_10_claimed'] as bool?) ?? false,
      hasUnbeatenTitle: (map['has_unbeaten_title'] as bool?) ?? false,
      achievementUnbeatenChampionClaimed: (map['achievement_unbeaten_champion_claimed'] as bool?) ?? false,
      achievementMaxFacilityClaimed: (map['achievement_max_facility_claimed'] as bool?) ?? false,
      longestLoginStreak: (map['longest_login_streak'] as num?)?.toInt() ?? 0,
      achievement45DayStreakClaimed: (map['achievement_45_day_streak_claimed'] as bool?) ?? false,
      dailyStreakDay: (map['daily_streak_day'] as num?)?.toInt() ?? 0,
      lastDailyClaimDate: map['last_daily_claim_date'] != null ? DateTime.tryParse(map['last_daily_claim_date'] as String) : null,
      socialInstagramFollowed: (map['social_instagram_followed'] as bool?) ?? false,
      socialXFollowed: (map['social_x_followed'] as bool?) ?? false,
      socialTiktokFollowed: (map['social_tiktok_followed'] as bool?) ?? false,
      socialEngagementClaimed: (map['social_engagement_claimed'] as bool?) ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'email': email,
      'language': language,
      'fcm_token': fcmToken,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

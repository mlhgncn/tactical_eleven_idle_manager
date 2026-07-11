class LeagueClubOption {
  final String clubId;
  final String clubName;
  final int quality;
  final bool isPremiumLocked;
  final int? premiumUnlockCost;

  LeagueClubOption({
    required this.clubId,
    required this.clubName,
    required this.quality,
    required this.isPremiumLocked,
    this.premiumUnlockCost,
  });

  factory LeagueClubOption.fromMap(Map<String, dynamic> map) {
    return LeagueClubOption(
      clubId: map['club_id'] as String,
      clubName: map['club_name'] as String,
      quality: (map['quality'] as num).toInt(),
      isPremiumLocked: map['is_premium_locked'] as bool,
      premiumUnlockCost: (map['premium_unlock_cost'] as num?)?.toInt(),
    );
  }
}

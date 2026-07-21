class WeeklyQuest {
  final String questKey;
  final String metric;
  final int target;
  final int gpReward;
  final int diamondReward;
  final int progress;
  final bool claimed;
  final DateTime? completedAt;

  const WeeklyQuest({
    required this.questKey,
    required this.metric,
    required this.target,
    required this.gpReward,
    required this.diamondReward,
    required this.progress,
    required this.claimed,
    this.completedAt,
  });

  bool get isComplete => progress >= target;

  factory WeeklyQuest.fromMap(Map<String, dynamic> map) {
    return WeeklyQuest(
      questKey: map['quest_key'] as String,
      metric: map['metric'] as String,
      target: (map['target'] as num).toInt(),
      gpReward: (map['gp_reward'] as num?)?.toInt() ?? 0,
      diamondReward: (map['diamond_reward'] as num?)?.toInt() ?? 0,
      progress: (map['progress'] as num?)?.toInt() ?? 0,
      claimed: map['claimed'] as bool? ?? false,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String) : null,
    );
  }
}

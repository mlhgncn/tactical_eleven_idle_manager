class MatchEvent {
  final String id;
  final String matchId;
  final int minute;
  final String eventType;
  final String? clubId;
  final String? playerId;
  final String? assistPlayerId;
  final String description;
  final DateTime createdAt;

  const MatchEvent({
    required this.id,
    required this.matchId,
    required this.minute,
    required this.eventType,
    this.clubId,
    this.playerId,
    this.assistPlayerId,
    required this.description,
    required this.createdAt,
  });

  factory MatchEvent.fromMap(Map<String, dynamic> map) {
    return MatchEvent(
      id: map['id'] as String,
      matchId: map['match_id'] as String,
      minute: (map['minute'] as num).toInt(),
      eventType: map['event_type'] as String,
      clubId: map['club_id'] as String?,
      playerId: map['player_id'] as String?,
      assistPlayerId: map['assist_player_id'] as String?,
      description: map['description'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}

enum Formation { f442, f433, f352, f532 }
enum Mentality { defensive, balanced, attacking }

class Tactics {
  final String clubId;
  Formation formation;
  Mentality mentality;
  String captainId;
  String penaltyTakerId;

  Tactics({
    required this.clubId,
    this.formation = Formation.f442,
    this.mentality = Mentality.balanced,
    required this.captainId,
    required this.penaltyTakerId,
  });

  factory Tactics.fromMap(Map<String, dynamic> map) {
    return Tactics(
      clubId: map['club_id'] as String,
      formation: Formation.values.firstWhere((value) => value.name == map['formation'] as String, orElse: () => Formation.f442),
      mentality: Mentality.values.firstWhere((value) => value.name == map['mentality'] as String, orElse: () => Mentality.balanced),
      captainId: map['captain_id'] as String? ?? '',
      penaltyTakerId: map['penalty_taker_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'club_id': clubId,
      'formation': formation.name,
      'mentality': mentality.name,
      'captain_id': captainId,
      'penalty_taker_id': penaltyTakerId,
    };
  }
}

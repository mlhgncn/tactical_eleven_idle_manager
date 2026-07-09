enum Formation { f442, f433, f352, f532 }
enum Mentality { defensive, balanced, attacking }

extension FormationLabel on Formation {
  String get label => switch (this) {
        Formation.f442 => '4-4-2',
        Formation.f433 => '4-3-3',
        Formation.f352 => '3-5-2',
        Formation.f532 => '5-3-2',
      };
}

class Tactics {
  final String clubId;
  Formation formation;
  Mentality mentality;
  String captainId;
  String penaltyTakerId;
  String freeKickTakerId;
  String cornerTakerId;
  int pressIntensity;
  int tempo;
  int defensiveLine;
  bool offsideTrap;
  bool timeWasting;

  Tactics({
    required this.clubId,
    this.formation = Formation.f442,
    this.mentality = Mentality.balanced,
    required this.captainId,
    required this.penaltyTakerId,
    String? freeKickTakerId,
    String? cornerTakerId,
    this.pressIntensity = 50,
    this.tempo = 50,
    this.defensiveLine = 50,
    this.offsideTrap = false,
    this.timeWasting = false,
  })  : freeKickTakerId = freeKickTakerId ?? penaltyTakerId,
        cornerTakerId = cornerTakerId ?? penaltyTakerId;

  factory Tactics.fromMap(Map<String, dynamic> map) {
    final penaltyTaker = map['penalty_taker_id'] as String? ?? '';
    return Tactics(
      clubId: map['club_id'] as String,
      formation: Formation.values.firstWhere((value) => value.name == map['formation'] as String, orElse: () => Formation.f442),
      mentality: Mentality.values.firstWhere((value) => value.name == map['mentality'] as String, orElse: () => Mentality.balanced),
      captainId: map['captain_id'] as String? ?? '',
      penaltyTakerId: penaltyTaker,
      freeKickTakerId: map['free_kick_taker_id'] as String? ?? penaltyTaker,
      cornerTakerId: map['corner_taker_id'] as String? ?? penaltyTaker,
      pressIntensity: (map['press_intensity'] as num?)?.toInt() ?? 50,
      tempo: (map['tempo'] as num?)?.toInt() ?? 50,
      defensiveLine: (map['defensive_line'] as num?)?.toInt() ?? 50,
      offsideTrap: (map['offside_trap'] as bool?) ?? false,
      timeWasting: (map['time_wasting'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'club_id': clubId,
      'formation': formation.name,
      'mentality': mentality.name,
      'captain_id': captainId,
      'penalty_taker_id': penaltyTakerId,
      'free_kick_taker_id': freeKickTakerId,
      'corner_taker_id': cornerTakerId,
      'press_intensity': pressIntensity,
      'tempo': tempo,
      'defensive_line': defensiveLine,
      'offside_trap': offsideTrap,
      'time_wasting': timeWasting,
    };
  }
}

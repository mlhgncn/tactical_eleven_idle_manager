enum Formation { f442, f433, f352, f532, f442b, f4231, f4141 }
enum Mentality { defensive, balanced, attacking }

extension FormationLabel on Formation {
  String get label => switch (this) {
        Formation.f442 => '4-4-2',
        Formation.f433 => '4-3-3',
        Formation.f352 => '3-5-2',
        Formation.f532 => '5-3-2',
        Formation.f442b => '4-4-2 (Elmas)',
        Formation.f4231 => '4-2-3-1',
        Formation.f4141 => '4-1-4-1',
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
  // One player id per formation slot, in slot order - null means "no manual
  // lineup set, auto-pick the best XI for the current formation".
  List<String>? startingElevenIds;

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
    this.startingElevenIds,
  })  : freeKickTakerId = freeKickTakerId ?? penaltyTakerId,
        cornerTakerId = cornerTakerId ?? penaltyTakerId;

  factory Tactics.fromMap(Map<String, dynamic> map) {
    final penaltyTaker = map['penalty_taker_id'] as String? ?? '';
    final rawStartingEleven = map['starting_eleven_ids'] as List<dynamic>?;
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
      startingElevenIds: rawStartingEleven?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    // These four are uuid columns server-side - an empty string (which
    // fromMap produces for "no player picked yet" when the DB value is
    // NULL) is not a valid uuid and Postgres rejects it with 22P02
    // ("invalid input syntax for type uuid") on save. Send NULL instead
    // whenever no real player id was ever assigned.
    String? orNull(String value) => value.isEmpty ? null : value;
    return {
      'club_id': clubId,
      'formation': formation.name,
      'mentality': mentality.name,
      'captain_id': orNull(captainId),
      'penalty_taker_id': orNull(penaltyTakerId),
      'free_kick_taker_id': orNull(freeKickTakerId),
      'corner_taker_id': orNull(cornerTakerId),
      'press_intensity': pressIntensity,
      'tempo': tempo,
      'defensive_line': defensiveLine,
      'offside_trap': offsideTrap,
      'time_wasting': timeWasting,
      'starting_eleven_ids': startingElevenIds,
    };
  }
}

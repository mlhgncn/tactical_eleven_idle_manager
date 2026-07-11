import 'tactics.dart';

class ScoutedPlayer {
  final String id;
  final String name;
  final String position;
  final int age;
  final int currentAbility;
  final bool isSuspended;
  final int injuryDurationWeeks;

  ScoutedPlayer({
    required this.id,
    required this.name,
    required this.position,
    required this.age,
    required this.currentAbility,
    required this.isSuspended,
    required this.injuryDurationWeeks,
  });

  bool get hasActiveInjury => injuryDurationWeeks > 0 || isSuspended;

  factory ScoutedPlayer.fromMap(Map<String, dynamic> map) {
    return ScoutedPlayer(
      id: map['id'] as String,
      name: map['name'] as String,
      position: map['position'] as String,
      age: (map['age'] as num).toInt(),
      currentAbility: (map['current_ability'] as num).toInt(),
      isSuspended: (map['is_suspended'] as bool?) ?? false,
      injuryDurationWeeks: (map['injury_duration_weeks'] as num?)?.toInt() ?? 0,
    );
  }
}

class ScoutedTactics {
  final Formation formation;
  final Mentality mentality;
  final List<String>? startingElevenIds;
  final int pressIntensity;
  final int tempo;
  final int defensiveLine;
  final bool offsideTrap;
  final bool timeWasting;

  ScoutedTactics({
    required this.formation,
    required this.mentality,
    required this.startingElevenIds,
    required this.pressIntensity,
    required this.tempo,
    required this.defensiveLine,
    required this.offsideTrap,
    required this.timeWasting,
  });

  factory ScoutedTactics.fromMap(Map<String, dynamic> map) {
    final rawStartingEleven = map['starting_eleven_ids'] as List<dynamic>?;
    return ScoutedTactics(
      formation: Formation.values.firstWhere(
        (value) => value.name == map['formation'] as String?,
        orElse: () => Formation.f442,
      ),
      mentality: Mentality.values.firstWhere(
        (value) => value.name == map['mentality'] as String?,
        orElse: () => Mentality.balanced,
      ),
      startingElevenIds: rawStartingEleven?.map((e) => e as String).toList(),
      pressIntensity: (map['press_intensity'] as num?)?.toInt() ?? 50,
      tempo: (map['tempo'] as num?)?.toInt() ?? 50,
      defensiveLine: (map['defensive_line'] as num?)?.toInt() ?? 50,
      offsideTrap: (map['offside_trap'] as bool?) ?? false,
      timeWasting: (map['time_wasting'] as bool?) ?? false,
    );
  }
}

class OpponentScoutReport {
  final String clubId;
  final List<ScoutedPlayer> players;
  final ScoutedTactics? tactics;

  OpponentScoutReport({
    required this.clubId,
    required this.players,
    required this.tactics,
  });

  factory OpponentScoutReport.fromMap(Map<String, dynamic> map) {
    final playersRaw = map['players'] as List<dynamic>? ?? const [];
    final tacticsRaw = map['tactics'] as Map<String, dynamic>?;
    return OpponentScoutReport(
      clubId: map['club_id'] as String,
      players: playersRaw.map((e) => ScoutedPlayer.fromMap(e as Map<String, dynamic>)).toList(),
      tactics: tacticsRaw != null ? ScoutedTactics.fromMap(tacticsRaw) : null,
    );
  }
}

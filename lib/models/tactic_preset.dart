import 'tactics.dart';

class TacticPreset {
  final String id;
  final String clubId;
  final String name;
  final Formation formation;
  final Mentality mentality;
  final int pressIntensity;
  final int tempo;
  final int defensiveLine;
  final bool offsideTrap;
  final bool timeWasting;

  const TacticPreset({
    required this.id,
    required this.clubId,
    required this.name,
    required this.formation,
    required this.mentality,
    required this.pressIntensity,
    required this.tempo,
    required this.defensiveLine,
    required this.offsideTrap,
    required this.timeWasting,
  });

  factory TacticPreset.fromMap(Map<String, dynamic> map) {
    return TacticPreset(
      id: map['id'] as String,
      clubId: map['club_id'] as String,
      name: map['name'] as String,
      formation: Formation.values.firstWhere((v) => v.name == map['formation'] as String, orElse: () => Formation.f442),
      mentality: Mentality.values.firstWhere((v) => v.name == map['mentality'] as String, orElse: () => Mentality.balanced),
      pressIntensity: (map['press_intensity'] as num?)?.toInt() ?? 50,
      tempo: (map['tempo'] as num?)?.toInt() ?? 50,
      defensiveLine: (map['defensive_line'] as num?)?.toInt() ?? 50,
      offsideTrap: map['offside_trap'] as bool? ?? false,
      timeWasting: map['time_wasting'] as bool? ?? false,
    );
  }
}

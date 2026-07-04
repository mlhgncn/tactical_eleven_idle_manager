class PlayerFM {
  final String id;
  final String? clubId;
  final String name;
  final String position;
  int age;
  int currentAbility;
  int potentialAbility;
  int morale;
  int fitness;
  int finishing;
  int passing;
  int tackling;
  int composure;
  int determination;
  int consistency;
  int injuryProneness;

  PlayerFM({
    required this.id,
    required this.clubId,
    required this.name,
    required this.position,
    required this.age,
    required this.currentAbility,
    required this.potentialAbility,
    this.morale = 75,
    this.fitness = 100,
    this.finishing = 10,
    this.passing = 10,
    this.tackling = 10,
    this.composure = 10,
    this.determination = 10,
    this.consistency = 10,
    this.injuryProneness = 5,
  });

  factory PlayerFM.fromMap(Map<String, dynamic> map) {
    return PlayerFM(
      id: map['id'] as String,
      clubId: map['club_id'] as String?,
      name: map['name'] as String,
      position: map['position'] as String,
      age: (map['age'] as num).toInt(),
      currentAbility: (map['current_ability'] as num).toInt(),
      potentialAbility: (map['potential_ability'] as num).toInt(),
      morale: (map['morale'] as num).toInt(),
      fitness: (map['fitness'] as num).toInt(),
      finishing: (map['finishing'] as num).toInt(),
      passing: (map['passing'] as num).toInt(),
      tackling: (map['tackling'] as num).toInt(),
      composure: (map['composure'] as num).toInt(),
      determination: (map['determination'] as num).toInt(),
      consistency: (map['consistency'] as num).toInt(),
      injuryProneness: (map['injury_proneness'] as num).toInt(),
    );
  }
}

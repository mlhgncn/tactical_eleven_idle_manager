class PlayerFM {
  final String id;
  final String clubId;
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
    required this.id, required this.clubId, required this.name, required this.position, required this.age,
    required this.currentAbility, required this.potentialAbility, this.morale = 75, this.fitness = 100,
    this.finishing = 10, this.passing = 10, this.tackling = 10, this.composure = 10, this.determination = 10,
    this.consistency = 10, this.injuryProneness = 5,
  });
}

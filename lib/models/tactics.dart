enum Formation { f442, f433, f352, f532 }
enum Mentality { defensive, balanced, attacking }

class Tactics {
  final String clubId;
  Formation formation;
  Mentality mentality;
  String captainId;
  String penaltyTakerId;

  Tactics({required this.clubId, this.formation = Formation.f442, this.mentality = Mentality.balanced, required this.captainId, required this.penaltyTakerId});
}

class ClubInfo {
  final String id;
  final String name;
  final int budget;
  final int stadiumCapacity;
  final int ticketPrice;
  final int trainingFacilityLevel;

  const ClubInfo({
    required this.id,
    required this.name,
    required this.budget,
    required this.stadiumCapacity,
    required this.ticketPrice,
    required this.trainingFacilityLevel,
  });

  ClubInfo copyWith({
    String? name,
    int? budget,
    int? stadiumCapacity,
    int? ticketPrice,
    int? trainingFacilityLevel,
  }) {
    return ClubInfo(
      id: id,
      name: name ?? this.name,
      budget: budget ?? this.budget,
      stadiumCapacity: stadiumCapacity ?? this.stadiumCapacity,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      trainingFacilityLevel: trainingFacilityLevel ?? this.trainingFacilityLevel,
    );
  }

  factory ClubInfo.fromMap(Map<String, dynamic> map) {
    return ClubInfo(
      id: map['id'] as String,
      name: map['name'] as String,
      budget: (map['budget'] as num).toInt(),
      stadiumCapacity: (map['stadium_capacity'] as num).toInt(),
      ticketPrice: (map['ticket_price'] as num).toInt(),
      trainingFacilityLevel: (map['training_facility_level'] as num).toInt(),
    );
  }
}

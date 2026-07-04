class ClubInfo {
  final String id;
  final String name;
  final int budget;
  final int stadiumCapacity;
  final int ticketPrice;
  final int trainingFacilityLevel;
  final int sponsorLevel; // 1-5 sponsor seviyesi
  final DateTime? lastMaintenanceDate; // Aylık bakım takibi

  const ClubInfo({
    required this.id,
    required this.name,
    required this.budget,
    required this.stadiumCapacity,
    required this.ticketPrice,
    required this.trainingFacilityLevel,
    this.sponsorLevel = 1,
    this.lastMaintenanceDate,
  });

  ClubInfo copyWith({
    String? name,
    int? budget,
    int? stadiumCapacity,
    int? ticketPrice,
    int? trainingFacilityLevel,
    int? sponsorLevel,
    DateTime? lastMaintenanceDate,
  }) {
    return ClubInfo(
      id: id,
      name: name ?? this.name,
      budget: budget ?? this.budget,
      stadiumCapacity: stadiumCapacity ?? this.stadiumCapacity,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      trainingFacilityLevel: trainingFacilityLevel ?? this.trainingFacilityLevel,
      sponsorLevel: sponsorLevel ?? this.sponsorLevel,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
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
      sponsorLevel: (map['sponsor_level'] as num?)?.toInt() ?? 1,
      lastMaintenanceDate: map['last_maintenance_date'] != null ? DateTime.parse(map['last_maintenance_date'] as String) : null,
    );
  }
}

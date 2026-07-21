class ClubInfo {
  final String id;
  final String name;
  final String? leagueId;
  final int budget;
  final int blockedBudget;
  final int stadiumCapacity;
  final int ticketPrice;
  final int trainingFacilityLevel;
  final int ticketPriceLevel;
  final int sponsorLevel; // 1-5 sponsor seviyesi
  final DateTime? lastMaintenanceDate; // Aylık bakım takibi
  final DateTime? sponsorUpgradeCompletesAt;
  final String? developmentUpgradeType; // 'stadium' | 'facility'
  final int? developmentTargetValue;
  final DateTime? developmentCompletesAt;
  final int developmentAdUses;
  final String? tacticHiddenForMatchId;
  final int freeTacticHidesThisSeason;
  final int tacticHideCharges;
  final String? campActiveForMatchId;
  final int freeCampUsesThisSeason;
  final int campCharges;
  final String? pendingSeasonEndSeasonId;
  final DateTime? academyCompletesAt;
  final int academyAdUses;

  const ClubInfo({
    required this.id,
    required this.name,
    this.leagueId,
    required this.budget,
    this.blockedBudget = 0,
    required this.stadiumCapacity,
    required this.ticketPrice,
    required this.trainingFacilityLevel,
    this.ticketPriceLevel = 1,
    this.sponsorLevel = 1,
    this.lastMaintenanceDate,
    this.sponsorUpgradeCompletesAt,
    this.developmentUpgradeType,
    this.developmentTargetValue,
    this.developmentCompletesAt,
    this.developmentAdUses = 0,
    this.tacticHiddenForMatchId,
    this.freeTacticHidesThisSeason = 0,
    this.tacticHideCharges = 0,
    this.campActiveForMatchId,
    this.freeCampUsesThisSeason = 0,
    this.campCharges = 0,
    this.pendingSeasonEndSeasonId,
    this.academyCompletesAt,
    this.academyAdUses = 0,
  });

  bool get hasTacticHideAvailable => freeTacticHidesThisSeason > 0 || tacticHideCharges > 0;
  bool get hasCampAvailable => freeCampUsesThisSeason > 0 || campCharges > 0;
  bool get isAcademyProducing => academyCompletesAt != null && academyCompletesAt!.isAfter(DateTime.now());

  bool get isSponsorUpgrading =>
      sponsorUpgradeCompletesAt != null && sponsorUpgradeCompletesAt!.isAfter(DateTime.now());

  bool get isDevelopmentUpgrading =>
      developmentCompletesAt != null && developmentCompletesAt!.isAfter(DateTime.now());

  ClubInfo copyWith({
    String? name,
    int? budget,
    int? blockedBudget,
    int? stadiumCapacity,
    int? ticketPrice,
    int? trainingFacilityLevel,
    int? ticketPriceLevel,
    int? sponsorLevel,
    DateTime? lastMaintenanceDate,
    DateTime? sponsorUpgradeCompletesAt,
    String? developmentUpgradeType,
    int? developmentTargetValue,
    DateTime? developmentCompletesAt,
    int? developmentAdUses,
    String? tacticHiddenForMatchId,
    int? freeTacticHidesThisSeason,
    int? tacticHideCharges,
    String? campActiveForMatchId,
    int? freeCampUsesThisSeason,
    int? campCharges,
    DateTime? academyCompletesAt,
    int? academyAdUses,
  }) {
    return ClubInfo(
      id: id,
      name: name ?? this.name,
      leagueId: leagueId,
      budget: budget ?? this.budget,
      blockedBudget: blockedBudget ?? this.blockedBudget,
      stadiumCapacity: stadiumCapacity ?? this.stadiumCapacity,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      trainingFacilityLevel: trainingFacilityLevel ?? this.trainingFacilityLevel,
      ticketPriceLevel: ticketPriceLevel ?? this.ticketPriceLevel,
      sponsorLevel: sponsorLevel ?? this.sponsorLevel,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      sponsorUpgradeCompletesAt: sponsorUpgradeCompletesAt ?? this.sponsorUpgradeCompletesAt,
      developmentUpgradeType: developmentUpgradeType ?? this.developmentUpgradeType,
      developmentTargetValue: developmentTargetValue ?? this.developmentTargetValue,
      developmentCompletesAt: developmentCompletesAt ?? this.developmentCompletesAt,
      developmentAdUses: developmentAdUses ?? this.developmentAdUses,
      tacticHiddenForMatchId: tacticHiddenForMatchId ?? this.tacticHiddenForMatchId,
      freeTacticHidesThisSeason: freeTacticHidesThisSeason ?? this.freeTacticHidesThisSeason,
      tacticHideCharges: tacticHideCharges ?? this.tacticHideCharges,
      campActiveForMatchId: campActiveForMatchId ?? this.campActiveForMatchId,
      freeCampUsesThisSeason: freeCampUsesThisSeason ?? this.freeCampUsesThisSeason,
      campCharges: campCharges ?? this.campCharges,
      academyCompletesAt: academyCompletesAt ?? this.academyCompletesAt,
      academyAdUses: academyAdUses ?? this.academyAdUses,
    );
  }

  factory ClubInfo.fromMap(Map<String, dynamic> map) {
    return ClubInfo(
      id: map['id'] as String,
      name: map['name'] as String,
      leagueId: map['league_id'] as String?,
      budget: (map['budget'] as num).toInt(),
      blockedBudget: (map['blocked_budget'] as num?)?.toInt() ?? 0,
      stadiumCapacity: (map['stadium_capacity'] as num).toInt(),
      ticketPrice: (map['ticket_price'] as num).toInt(),
      trainingFacilityLevel: (map['training_facility_level'] as num).toInt(),
      ticketPriceLevel: (map['ticket_price_level'] as num?)?.toInt() ?? 1,
      sponsorLevel: (map['sponsor_level'] as num?)?.toInt() ?? 1,
      lastMaintenanceDate: map['last_maintenance_date'] != null ? DateTime.parse(map['last_maintenance_date'] as String) : null,
      sponsorUpgradeCompletesAt: map['sponsor_upgrade_completes_at'] != null
          ? DateTime.tryParse(map['sponsor_upgrade_completes_at'] as String)
          : null,
      developmentUpgradeType: map['development_upgrade_type'] as String?,
      developmentTargetValue: (map['development_target_value'] as num?)?.toInt(),
      developmentCompletesAt: map['development_completes_at'] != null
          ? DateTime.tryParse(map['development_completes_at'] as String)
          : null,
      developmentAdUses: (map['development_ad_uses'] as num?)?.toInt() ?? 0,
      tacticHiddenForMatchId: map['tactic_hidden_for_match_id'] as String?,
      freeTacticHidesThisSeason: (map['free_tactic_hides_this_season'] as num?)?.toInt() ?? 0,
      tacticHideCharges: (map['tactic_hide_charges'] as num?)?.toInt() ?? 0,
      campActiveForMatchId: map['camp_active_for_match_id'] as String?,
      freeCampUsesThisSeason: (map['free_camp_uses_this_season'] as num?)?.toInt() ?? 0,
      campCharges: (map['camp_charges'] as num?)?.toInt() ?? 0,
      pendingSeasonEndSeasonId: map['pending_season_end_season_id'] as String?,
      academyCompletesAt: map['academy_completes_at'] != null
          ? DateTime.tryParse(map['academy_completes_at'] as String)
          : null,
      academyAdUses: (map['academy_ad_uses'] as num?)?.toInt() ?? 0,
    );
  }
}

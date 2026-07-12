import 'package:flutter_test/flutter_test.dart';
import 'package:tactical_eleven_idle_manager/models/club_info.dart';
import 'package:tactical_eleven_idle_manager/models/player_fm.dart';
import 'package:tactical_eleven_idle_manager/models/match_result.dart';

void main() {
  group('Economy System Tests', () {
    late ClubInfo testClub;
    late List<PlayerFM> testSquad;

    setUp(() {
      // Başlangıç ekonomisi kurulu
      testClub = const ClubInfo(
        id: 'test-club',
        name: 'Test Club',
        budget: 10000,
        stadiumCapacity: 5000,
        ticketPrice: 5,
        trainingFacilityLevel: 1,
        sponsorLevel: 1,
      );

      // 11 oyuncu (50-60 ability)
      testSquad = List<PlayerFM>.generate(
        11,
        (index) => PlayerFM(
          id: 'player-$index',
          clubId: testClub.id,
          name: 'Player $index',
          position: 'Pos',
          age: 25,
          currentAbility: 50 + index,
          potentialAbility: 60 + index,
          morale: 80,
          fitness: 90,
          finishing: 70,
          passing: 65,
          tackling: 60,
          composure: 62,
          determination: 68,
          consistency: 70,
          injuryProneness: 10,
        ),
      );
    });

    test('Calculate match win economy', () {
      // Maç kazanma: 3-1
      final result = MatchResult(
        homeTeamId: testClub.id,
        awayTeamId: 'away-1',
        homeScore: 3,
        awayScore: 1,
        homeShots: 10,
        awayShots: 5,
        homeXg: 3.2,
        awayXg: 1.1,
        homePossession: 60,
        commentary: ['Match won'],
        events: [],
      );

      // === EKONOMI HESAPLAMASI ===
      // 1. Stadyum Geliri: (Kapasitesi * Bilet Fiyatı * 30% doluluk)
      final stadiumRevenue = (testClub.stadiumCapacity * testClub.ticketPrice) ~/ 8;
      expect(stadiumRevenue, equals(3125)); // 5000 * 5 / 8 = 3125

      // 2. Sponsor Geliri: Sponsor seviyesi * 500 GP
      final sponsorRevenue = testClub.sponsorLevel * 500;
      expect(sponsorRevenue, equals(500));

      // 3. Maç Bonusu: Kazanma = +300
      int matchBonus = result.homeScore > result.awayScore ? 300 : -200;
      expect(matchBonus, equals(300));

      // 4. Oyuncu Maliyeti: Her oyuncu ability * 2 GP per maç
      int playerWages = 0;
      for (final player in testSquad) {
        playerWages += (player.currentAbility * 2).toInt();
      }
      // 11 oyuncu: (50*2) + (51*2) + ... + (60*2) = 2*605 = 1210
      expect(playerWages, equals(1210));

      // 5. Bakım Masrafı: Stadyum kapasitesi/200 + Tesis seviyesi*25
      final maintenanceCost = (testClub.stadiumCapacity ~/ 200) + (testClub.trainingFacilityLevel * 25);
      expect(maintenanceCost, equals(50)); // 5000/200 + 1*25 = 25 + 25 = 50

      final totalRevenue = stadiumRevenue + sponsorRevenue + matchBonus;
      final totalExpense = playerWages + maintenanceCost;
      final netIncome = totalRevenue - totalExpense;

      expect(totalRevenue, equals(3925)); // 3125 + 500 + 300
      expect(totalExpense, equals(1260)); // 1210 + 50
      expect(netIncome, equals(2665)); // 3925 - 1260

      // Yeni bütçe
      final newBudget = testClub.budget + netIncome;
      expect(newBudget, equals(12665)); // 10000 + 2665
    });

    test('Calculate match loss economy', () {
      // Maç kaybetme: 0-2
      final result = MatchResult(
        homeTeamId: testClub.id,
        awayTeamId: 'away-1',
        homeScore: 0,
        awayScore: 2,
        homeShots: 3,
        awayShots: 8,
        homeXg: 0.5,
        awayXg: 2.1,
        homePossession: 35,
        commentary: ['Match lost'],
        events: [],
      );

      final stadiumRevenue = (testClub.stadiumCapacity * testClub.ticketPrice) ~/ 8;
      final sponsorRevenue = testClub.sponsorLevel * 500;
      int matchBonus = result.homeScore > result.awayScore ? 300 : -200;
      expect(matchBonus, equals(-200));

      int playerWages = 0;
      for (final player in testSquad) {
        playerWages += (player.currentAbility * 2).toInt();
      }

      final maintenanceCost = (testClub.stadiumCapacity ~/ 200) + (testClub.trainingFacilityLevel * 25);
      final totalRevenue = stadiumRevenue + sponsorRevenue + matchBonus;
      final totalExpense = playerWages + maintenanceCost;
      final netIncome = totalRevenue - totalExpense;

      expect(totalRevenue, equals(3425)); // 3125 + 500 - 200
      expect(totalExpense, equals(1260));
      expect(netIncome, equals(2165)); // Kaybetse bile kazanç (stadyum geliri büyük)

      final newBudget = testClub.budget + netIncome;
      expect(newBudget, equals(12165));
    });

    test('Upgrade costs are reasonable', () {
      // Tesis yükseltme maliyeti: 2000 + (seviye * 1500)
      final facilityCost = 2000 + (testClub.trainingFacilityLevel * 1500);
      expect(facilityCost, equals(3500)); // Level 1 -> 2 = 3500 GP

      // Stadyum yükseltme: 1000 + (yeni kapasitesi / 1000)
      final stadiumUpgradeCost = 1000 + (10000 ~/ 1000); // 10K kapasiteye yükselt
      expect(stadiumUpgradeCost, equals(1010));

      // Sponsor yükseltme: 5000 * current_level
      final sponsorUpgradeCost = 5000 * testClub.sponsorLevel;
      expect(sponsorUpgradeCost, equals(5000)); // Level 1 -> 2 = 5000 GP
    });

    test('With 7 matches per week (full week)', () {
      // Haftada 7 maç, hepsi kazanma
      const matchesPerWeek = 7;
      
      final stadiumRevenue = (testClub.stadiumCapacity * testClub.ticketPrice) ~/ 8;
      final sponsorRevenue = testClub.sponsorLevel * 500;
      const matchBonus = 300;

      int playerWages = 0;
      for (final player in testSquad) {
        playerWages += (player.currentAbility * 2).toInt();
      }

      final maintenanceCost = (testClub.stadiumCapacity ~/ 200) + (testClub.trainingFacilityLevel * 25);
      final perMatchIncome = stadiumRevenue + sponsorRevenue + matchBonus - playerWages - maintenanceCost;

      final weeklyIncome = perMatchIncome * matchesPerWeek;
      final monthlyIncome = weeklyIncome * 4;

      print('Per match income: $perMatchIncome GP');
      print('Weekly income: $weeklyIncome GP');
      print('Monthly income: $monthlyIncome GP');

      // ~2665 per match * 7 = ~18,655 per week
      // ~18,655 * 4 = ~74,620 per month

      // Tesis upgrade'e ne kadar sürer? 3500 GP / 2665 = 1.3 maç = hâlâ hızlı
      // Bu normalized: başlangıçta çabuk upgrade, sonra zorlasıyor

      expect(weeklyIncome, greaterThan(15000));
      expect(monthlyIncome, greaterThan(60000));
    });
  });
}

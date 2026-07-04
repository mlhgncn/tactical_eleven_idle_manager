import 'dart:math';

import '../models/match_result.dart';
import '../models/player_fm.dart';
import '../models/tactics.dart';

class MatchRepository {
  final Random _random = Random();

  MatchResult simulateMatch({
    required String homeTeamId,
    required String awayTeamId,
    required String homeTeamName,
    required String awayTeamName,
    required List<PlayerFM> homeSquad,
    required List<PlayerFM> awaySquad,
    required Tactics homeTactics,
    required Tactics awayTactics,
  }) {
    final homeMetrics = _calculateTeamMetrics(homeSquad, homeTactics, isHome: true);
    final awayMetrics = _calculateTeamMetrics(awaySquad, awayTactics, isHome: false);

    final homeScore = _calculateGoals(homeMetrics, awayMetrics);
    final awayScore = _calculateGoals(awayMetrics, homeMetrics);

    final homeShots = (homeMetrics.offense * 0.65).round() + homeScore * 3;
    final awayShots = (awayMetrics.offense * 0.6).round() + awayScore * 3;

    final homeXg = (homeMetrics.offense / max(awayMetrics.defense, 1)) * 1.2;
    final awayXg = (awayMetrics.offense / max(homeMetrics.defense, 1)) * 1.0;

    return MatchResult(
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
      homeScore: homeScore,
      awayScore: awayScore,
      homeShots: homeShots,
      awayShots: awayShots,
      homeXg: double.parse(homeXg.toStringAsFixed(2)),
      awayXg: double.parse(awayXg.toStringAsFixed(2)),
      homePossession: _calculatePossession(homeMetrics, awayMetrics),
      commentary: _buildCommentary(homeScore, awayScore, homeTeamName, awayTeamName, homeMetrics, awayMetrics),
    );
  }

  _TeamMetrics _calculateTeamMetrics(List<PlayerFM> squad, Tactics tactics, {required bool isHome}) {
    if (squad.isEmpty) {
      return _TeamMetrics(offense: 10, defense: 10, fitness: 50, morale: 50, discipline: 50, injuryRisk: 5);
    }

    final abilityTotal = squad.fold<int>(0, (sum, player) => sum + player.currentAbility);
    final finishingTotal = squad.fold<int>(0, (sum, player) => sum + player.finishing);
    final passingTotal = squad.fold<int>(0, (sum, player) => sum + player.passing);
    final tacklingTotal = squad.fold<int>(0, (sum, player) => sum + player.tackling);
    final composureTotal = squad.fold<int>(0, (sum, player) => sum + player.composure);
    final fitnessTotal = squad.fold<int>(0, (sum, player) => sum + player.fitness);
    final moraleTotal = squad.fold<int>(0, (sum, player) => sum + player.morale);
    final consistencyTotal = squad.fold<int>(0, (sum, player) => sum + player.consistency);
    final injuryRiskTotal = squad.fold<int>(0, (sum, player) => sum + player.injuryProneness);

    final averageAbility = abilityTotal / squad.length;
    final averageFinishing = finishingTotal / squad.length;
    final averagePassing = passingTotal / squad.length;
    final averageTackling = tacklingTotal / squad.length;
    final averageComposure = composureTotal / squad.length;
    final averageFitness = fitnessTotal / squad.length;
    final averageMorale = moraleTotal / squad.length;
    final averageConsistency = consistencyTotal / squad.length;
    final averageInjuryRisk = injuryRiskTotal / squad.length;

    final mentalityAttack = switch (tactics.mentality) {
      Mentality.attacking => 12,
      Mentality.balanced => 6,
      Mentality.defensive => 2,
    };
    final mentalityDefense = switch (tactics.mentality) {
      Mentality.attacking => 3,
      Mentality.balanced => 6,
      Mentality.defensive => 12,
    };
    final formationAttack = switch (tactics.formation) {
      Formation.f442 => 6,
      Formation.f433 => 8,
      Formation.f352 => 10,
      Formation.f532 => 4,
    };
    final formationDefense = switch (tactics.formation) {
      Formation.f442 => 8,
      Formation.f433 => 6,
      Formation.f352 => 5,
      Formation.f532 => 10,
    };

    final fitnessModifier = (averageFitness - 75) * 0.4;
    final moraleModifier = (averageMorale - 70) * 0.25;
    final disciplinePenalty = (100 - averageConsistency) * 0.2;
    final injuryPenalty = (averageInjuryRisk - 20) * 0.15;
    final homeAdvantage = isHome ? 7 : 0;

    final offense = (averageAbility * 0.55) + (averageFinishing * 0.35) + (averagePassing * 0.25) + mentalityAttack + formationAttack + fitnessModifier + moraleModifier + homeAdvantage - disciplinePenalty;
    final defense = (averageAbility * 0.45) + (averageTackling * 0.4) + (averageComposure * 0.25) + mentalityDefense + formationDefense + fitnessModifier + moraleModifier + homeAdvantage - injuryPenalty;

    return _TeamMetrics(
      offense: offense.round().clamp(20, 120),
      defense: defense.round().clamp(20, 120),
      fitness: averageFitness.round(),
      morale: averageMorale.round(),
      discipline: averageConsistency.round(),
      injuryRisk: averageInjuryRisk.round(),
    );
  }

  int _calculateGoals(_TeamMetrics offenseMetrics, _TeamMetrics defenseMetrics) {
    final raw = (offenseMetrics.offense / max(defenseMetrics.defense, 1)) * 1.5;
    final variability = (_random.nextDouble() * 2) - 0.8;
    final score = (raw + variability).clamp(0, 6).round();
    return score;
  }

  int _calculatePossession(_TeamMetrics home, _TeamMetrics away) {
    final homeBase = home.offense + home.defense;
    final awayBase = away.offense + away.defense;
    if (homeBase + awayBase == 0) return 50;
    return ((homeBase / (homeBase + awayBase)) * 100).round();
  }

  List<String> _buildCommentary(int homeScore, int awayScore, String homeTeamName, String awayTeamName, _TeamMetrics homeMetrics, _TeamMetrics awayMetrics) {
    final commentary = <String>[];
    commentary.add('Maç başladı: $homeTeamName vs $awayTeamName');

    if (homeMetrics.fitness < 60) {
      commentary.add('$homeTeamName düşük kondisyonla başladı.');
    }
    if (awayMetrics.morale > 75) {
      commentary.add('$awayTeamName yüksek moralle hücum ediyor.');
    }
    if (homeMetrics.discipline < 60) {
      commentary.add('$homeTeamName sert fauller yapıyor, kart tehlikesi var.');
    }
    if (awayMetrics.injuryRisk > 30) {
      commentary.add('$awayTeamName sakatlık riski altında.');
    }

    if (homeScore > awayScore) {
      commentary.add('$homeTeamName maçta üstünlüğü ele geçirdi.');
      commentary.add('Maç sonu skoru: $homeScore - $awayScore');
    } else if (awayScore > homeScore) {
      commentary.add('$awayTeamName baskın oynadı.');
      commentary.add('Maç sonu skoru: $homeScore - $awayScore');
    } else {
      commentary.add('Maç karşılıklı ataklarla geçti.');
      commentary.add('Maç sonu skoru: $homeScore - $awayScore');
    }

    return commentary;
  }
}

class _TeamMetrics {
  final int offense;
  final int defense;
  final int fitness;
  final int morale;
  final int discipline;
  final int injuryRisk;

  _TeamMetrics({
    required this.offense,
    required this.defense,
    required this.fitness,
    required this.morale,
    required this.discipline,
    required this.injuryRisk,
  });
}

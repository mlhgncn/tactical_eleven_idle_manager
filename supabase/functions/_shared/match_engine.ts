// Shared match-resolution engine used by both play_next_fixture (interactive,
// one match, triggered by the owning user tapping "Maçı Oyna") and
// auto_resolve_matches (batch, triggered by pg_cron for matches whose
// kickoff time has passed - the OSM-style "matches happen on schedule
// whether or not you're online" path). Keeping the simulation logic in one
// place means both entry points produce identical, consistent results.

export interface MatchRow {
  id: string;
  home_club_id: string;
  away_club_id: string;
  match_date: string;
}

export interface ClubRow {
  id: string;
  budget: number;
  stadium_capacity: number | null;
  ticket_price: number | null;
  training_facility_level: number | null;
  sponsor_level: number | null;
  user_id: string | null;
}

interface ClubTactic {
  club_id: string;
  mentality: string | null;
  formation: string | null;
  press_intensity: number | null;
  tempo: number | null;
  defensive_line: number | null;
  offside_trap: boolean | null;
  time_wasting: boolean | null;
  free_kick_taker_id: string | null;
  corner_taker_id: string | null;
}

interface TacticSnapshot {
  mentality: string | null;
  formation: string | null;
  pressIntensity: number;
  tempo: number;
  defensiveLine: number;
  offsideTrap: boolean;
  timeWasting: boolean;
  freeKickTakerId: string | null;
  cornerTakerId: string | null;
}

const DEFAULT_TACTIC: TacticSnapshot = {
  mentality: 'balanced',
  formation: 'f442',
  pressIntensity: 50,
  tempo: 50,
  defensiveLine: 50,
  offsideTrap: false,
  timeWasting: false,
  freeKickTakerId: null,
  cornerTakerId: null,
};

export interface PlayerRow {
  id: string;
  name: string;
  club_id: string | null;
  position: string;
  current_ability: number;
  age: number;
  injury_proneness: number;
  fitness: number;
  morale: number;
  finishing: number;
  passing: number;
  tackling: number;
  composure: number;
  determination: number;
  injury_duration_weeks: number;
  is_suspended: boolean;
  injury_type: string | null;
}

type PositionGroup = 'GK' | 'DEF' | 'MID' | 'FOR';

function positionGroup(position: string | null): PositionGroup {
  const upper = (position ?? '').toUpperCase();
  if (upper === 'GK') return 'GK';
  if (['CB', 'LB', 'RB', 'WB', 'LWB', 'RWB', 'FB'].some((p) => upper.startsWith(p))) return 'DEF';
  if (['CM', 'CDM', 'CAM', 'LM', 'RM', 'DM', 'AM'].some((p) => upper.startsWith(p))) return 'MID';
  return 'FOR';
}

// Classic rock-paper-scissors formation matchups: each entry is the attack
// modifier a formation gets when facing the given opponent formation.
const FORMATION_MATCHUPS: Record<string, Record<string, number>> = {
  f442: { f442: 0, f433: 0.04, f352: -0.03, f532: 0.02 },
  f433: { f442: -0.02, f433: 0, f352: 0.02, f532: 0.05 },
  f352: { f442: 0.05, f433: -0.03, f352: 0, f532: 0.01 },
  f532: { f442: -0.01, f433: -0.04, f352: 0.04, f532: 0 },
};

function formationMatchupModifier(own: string | null, opponent: string | null): number {
  const ownKey = (own ?? 'f442').toLowerCase();
  const oppKey = (opponent ?? 'f442').toLowerCase();
  return FORMATION_MATCHUPS[ownKey]?.[oppKey] ?? 0;
}

function mentalityModifier(mentality: string | null): { attack: number; defense: number } {
  switch (mentality?.toLowerCase()) {
    case 'attacking':
      return { attack: 0.12, defense: -0.08 };
    case 'defensive':
      return { attack: -0.08, defense: 0.12 };
    case 'balanced':
    default:
      return { attack: 0, defense: 0 };
  }
}

function normalizedDelta(value: number): number {
  return (value - 50) / 50; // 0 -> -1, 50 -> 0, 100 -> 1
}

// A good dedicated free-kick/corner taker (finishing for free kicks, passing
// for corner delivery, relative to their own squad's average) nudges attack
// output slightly - capped small since this is a refinement, not a
// dominant factor like mentality or formation.
function setPieceBonus(players: PlayerRow[], takerId: string | null, statKey: 'finishing' | 'passing'): number {
  if (!takerId || players.length === 0) return 0;
  const taker = players.find((p) => p.id === takerId);
  if (!taker) return 0;
  const squadAvg = players.reduce((sum, p) => sum + (p[statKey] ?? 10), 0) / players.length;
  const delta = ((taker[statKey] ?? 10) - squadAvg) / 20;
  return Math.max(-0.02, Math.min(0.02, delta * 0.02));
}

// "Riskli ama etkili" (risky but effective), per the tactics screen's own
// description: usually suppresses the opponent's attack, but can
// occasionally be played through and backfire.
function offsideTrapEffect(enabled: boolean): number {
  if (!enabled) return 0;
  return Math.random() < 0.72 ? -0.06 : 0.05;
}

function averageMorale(players: PlayerRow[]): number {
  if (players.length === 0) return 75;
  return players.reduce((sum, p) => sum + (p.morale ?? 75), 0) / players.length;
}

function phaseRating(players: PlayerRow[], group: PositionGroup): number {
  const groupPlayers = players.filter((p) => positionGroup(p.position) === group);
  const pool = groupPlayers.length > 0 ? groupPlayers : players;
  if (pool.length === 0) return 50;

  const statFor = (p: PlayerRow): number => {
    switch (group) {
      case 'DEF':
        return p.current_ability * 0.5 + p.tackling * 3 + p.composure * 1.5;
      case 'MID':
        return p.current_ability * 0.5 + p.passing * 2.5 + p.determination * 1.5;
      case 'FOR':
        return p.current_ability * 0.5 + p.finishing * 3 + p.composure * 1.5;
      default:
        return p.current_ability;
    }
  };

  return pool.reduce((sum, p) => sum + statFor(p), 0) / pool.length;
}

function blendedRating(abilityRating: number, tacticalModifier: number, moraleAvg: number): number {
  const tacticalScore = 50 + tacticalModifier * 200 + (moraleAvg - 75) * 0.6;
  return abilityRating * 0.7 + tacticalScore * 0.3;
}

function makeExpectedGoals(
  homePlayers: PlayerRow[],
  awayPlayers: PlayerRow[],
  homeTactic: TacticSnapshot,
  awayTactic: TacticSnapshot,
) {
  const homeAttackAbility = phaseRating(homePlayers, 'FOR');
  const homeDefenseAbility = phaseRating(homePlayers, 'DEF');
  const homeMidAbility = phaseRating(homePlayers, 'MID');
  const awayAttackAbility = phaseRating(awayPlayers, 'FOR');
  const awayDefenseAbility = phaseRating(awayPlayers, 'DEF');
  const awayMidAbility = phaseRating(awayPlayers, 'MID');

  const homeMentalityMod = mentalityModifier(homeTactic.mentality);
  const awayMentalityMod = mentalityModifier(awayTactic.mentality);
  const homeFormationMod = formationMatchupModifier(homeTactic.formation, awayTactic.formation);
  const awayFormationMod = formationMatchupModifier(awayTactic.formation, homeTactic.formation);

  // Press: disrupts the OPPONENT's attack, doesn't boost your own directly.
  const homePressMod = normalizedDelta(homeTactic.pressIntensity) * 0.05;
  const awayPressMod = normalizedDelta(awayTactic.pressIntensity) * 0.05;
  // Tempo: more direct/urgent play boosts your own attack output.
  const homeTempoMod = normalizedDelta(homeTactic.tempo) * 0.05;
  const awayTempoMod = normalizedDelta(awayTactic.tempo) * 0.05;
  // Defensive line: pushing up boosts your own attack but opens up space
  // in behind - the opponent's counter-attack threat rises with it.
  const homeLineMod = normalizedDelta(homeTactic.defensiveLine) * 0.04;
  const awayLineMod = normalizedDelta(awayTactic.defensiveLine) * 0.04;
  const homeLineCounterRisk = normalizedDelta(homeTactic.defensiveLine) * 0.035;
  const awayLineCounterRisk = normalizedDelta(awayTactic.defensiveLine) * 0.035;
  const homeOffsideEffect = offsideTrapEffect(homeTactic.offsideTrap);
  const awayOffsideEffect = offsideTrapEffect(awayTactic.offsideTrap);
  // Time-wasting: patient possession retention trims some threat off both
  // ends - a simplified, whole-match proxy for "hold the ball late while
  // leading" since xG here is computed before the scoreline is known.
  const homeTimeWasteMod = homeTactic.timeWasting ? -0.01 : 0;
  const awayTimeWasteMod = awayTactic.timeWasting ? -0.01 : 0;
  const homeSetPieceMod = setPieceBonus(homePlayers, homeTactic.freeKickTakerId, 'finishing') +
    setPieceBonus(homePlayers, homeTactic.cornerTakerId, 'passing');
  const awaySetPieceMod = setPieceBonus(awayPlayers, awayTactic.freeKickTakerId, 'finishing') +
    setPieceBonus(awayPlayers, awayTactic.cornerTakerId, 'passing');

  const homeMorale = averageMorale(homePlayers);
  const awayMorale = averageMorale(awayPlayers);

  const homeAttackMod = homeFormationMod + homeMentalityMod.attack + homeTempoMod + homeLineMod +
    homeSetPieceMod + homeTimeWasteMod - awayPressMod + awayLineCounterRisk + awayOffsideEffect;
  const awayAttackMod = awayFormationMod + awayMentalityMod.attack + awayTempoMod + awayLineMod +
    awaySetPieceMod + awayTimeWasteMod - homePressMod + homeLineCounterRisk + homeOffsideEffect;

  const homeAttack = blendedRating(homeAttackAbility, homeAttackMod, homeMorale);
  const homeDefense = blendedRating(homeDefenseAbility, homeMentalityMod.defense, homeMorale);
  const awayAttack = blendedRating(awayAttackAbility, awayAttackMod, awayMorale);
  const awayDefense = blendedRating(awayDefenseAbility, awayMentalityMod.defense, awayMorale);

  const midfieldDiff = (homeMidAbility - awayMidAbility) / 40;

  const homeXG = Math.max(0.3, 0.9 + (homeAttack - awayDefense) * 0.045 + midfieldDiff * 0.25 + 0.25);
  const awayXG = Math.max(0.3, 0.75 + (awayAttack - homeDefense) * 0.045 - midfieldDiff * 0.25);

  const homePossession = Math.round(
    (homeMidAbility / Math.max(1, homeMidAbility + awayMidAbility)) * 100,
  );

  const pressIntensityAvg = (homeTactic.pressIntensity + awayTactic.pressIntensity) / 2;

  return { homeXG, awayXG, homePossession, pressIntensityAvg };
}

function rollGoals(xg: number): number {
  let goals = 0;
  let chance = xg / 3.0;

  while (Math.random() < Math.min(0.75, chance)) {
    goals += 1;
    chance *= 0.65;
  }

  return goals;
}

function applyInjury(player: PlayerRow, matchIntensity: number): { injuryType: string; duration: number } | null {
  if (player.injury_duration_weeks > 0 || player.is_suspended) {
    return null;
  }

  const chance = 0.008 + (player.injury_proneness / 100) * 0.018 + Math.max(0, 100 - player.fitness) / 100 * 0.012 + matchIntensity * 0.006;
  if (Math.random() >= chance) {
    return null;
  }

  const injuryType = ['diz sakatlığı', 'kas yırtığı', 'bilek burkulması', 'sırt sakatlığı'][
    Math.floor(Math.random() * 4)
  ];
  const duration = Math.max(1, Math.min(6, Math.round(1 + player.age / 24 + player.injury_proneness / 12 + matchIntensity)));

  return { injuryType, duration };
}

function randomBetween(min: number, max: number) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function choosePlayer(players: PlayerRow[]) {
  if (players.length === 0) return null;
  return players[Math.floor(Math.random() * players.length)];
}

function createEvent(
  matchId: string,
  minute: number,
  eventType: string,
  clubId: string | null,
  playerId: string | null,
  assistPlayerId: string | null,
  description: string,
) {
  return {
    id: crypto.randomUUID(),
    match_id: matchId,
    minute,
    event_type: eventType,
    club_id: clubId,
    player_id: playerId,
    assist_player_id: assistPlayerId,
    description,
    created_at: new Date().toISOString(),
  };
}

export interface ClubEconomyResult {
  clubId: string;
  isHome: boolean;
  goalsFor: number;
  goalsAgainst: number;
  stadiumRevenue: number;
  sponsorRevenue: number;
  matchBonus: number;
  playerWages: number;
  maintenanceCost: number;
  totalRevenue: number;
  totalExpense: number;
  netIncome: number;
  newBudget: number;
}

export interface ResolvedMatch {
  matchId: string;
  homeClubId: string;
  awayClubId: string;
  homeScore: number;
  awayScore: number;
  homeShots: number;
  awayShots: number;
  homeXg: number;
  awayXg: number;
  homePossession: number;
  commentary: string[];
  events: Array<Record<string, unknown>>;
  economy: ClubEconomyResult[];
}

// deno-lint-ignore no-explicit-any
type SupabaseClientLike = any;

function computeClubEconomy(
  club: ClubRow,
  clubPlayers: PlayerRow[],
  isHome: boolean,
  goalsFor: number,
  goalsAgainst: number,
): ClubEconomyResult {
  const stadiumCapacity = Number(club.stadium_capacity ?? 15000);
  const ticketPrice = Number(club.ticket_price ?? 5);
  const trainingFacilityLevel = Number(club.training_facility_level ?? 1);
  const sponsorLevel = Number(club.sponsor_level ?? 1);
  const budget = Number(club.budget ?? 0);

  const matchBonus = goalsFor > goalsAgainst ? 300 : goalsFor === goalsAgainst ? 100 : -200;
  const playerWages = clubPlayers.reduce((sum, player) => sum + player.current_ability * 2, 0);
  // Only the home club sells tickets for this fixture.
  const stadiumRevenue = isHome ? Math.floor((stadiumCapacity * ticketPrice) / 3) : 0;
  const sponsorRevenue = sponsorLevel * 500;
  const maintenanceCost = Math.floor(stadiumCapacity / 200) + trainingFacilityLevel * 25;
  const totalRevenue = stadiumRevenue + sponsorRevenue + matchBonus;
  const totalExpense = playerWages + maintenanceCost;
  const netIncome = totalRevenue - totalExpense;

  return {
    clubId: club.id,
    isHome,
    goalsFor,
    goalsAgainst,
    stadiumRevenue,
    sponsorRevenue,
    matchBonus,
    playerWages,
    maintenanceCost,
    totalRevenue,
    totalExpense,
    netIncome,
    newBudget: budget + netIncome,
  };
}

// Resolves one match end-to-end: simulates the result, writes match_events,
// applies injuries, credits/debits BOTH clubs' economy (previously only the
// calling user's club was updated - the opponent's budget silently never
// moved), updates standings, and emails an inbox message to whichever side
// has a real owner. Marks the match as played atomically (the
// `.eq('is_played', false)` guard means a match already resolved by the
// scheduled cron can't also be double-resolved by a user's manual tap, and
// vice versa).
export async function resolveMatch(
  supabase: SupabaseClientLike,
  matchRow: MatchRow,
): Promise<ResolvedMatch | { alreadyPlayed: true }> {
  const clubIds = [matchRow.home_club_id, matchRow.away_club_id];

  const { data: clubRows, error: clubsError } = await supabase
    .from('clubs')
    .select('id,budget,stadium_capacity,ticket_price,training_facility_level,sponsor_level,user_id')
    .in('id', clubIds);
  if (clubsError) throw new Error(`Kulüp bilgileri alınamadı: ${clubsError.message}`);

  const clubMap = new Map<string, ClubRow>((clubRows ?? []).map((c: ClubRow) => [c.id, c]));
  const homeClub = clubMap.get(matchRow.home_club_id);
  const awayClub = clubMap.get(matchRow.away_club_id);
  if (!homeClub || !awayClub) {
    throw new Error('Ev sahibi veya deplasman kulübü bulunamadı.');
  }

  const { data: playerRows, error: playerError } = await supabase
    .from('players')
    .select('id,name,club_id,position,current_ability,age,injury_proneness,fitness,morale,finishing,passing,tackling,composure,determination,injury_duration_weeks,is_suspended,injury_type')
    .in('club_id', clubIds);
  if (playerError) throw new Error(`Oyuncu verileri alınamadı: ${playerError.message}`);

  const { data: tactics, error: tacticsError } = await supabase
    .from('tactics')
    .select('club_id,mentality,formation,press_intensity,tempo,defensive_line,offside_trap,time_wasting,free_kick_taker_id,corner_taker_id')
    .in('club_id', clubIds);
  if (tacticsError) throw new Error(`Taktikler okunamadı: ${tacticsError.message}`);

  const tacticMap = new Map<string, TacticSnapshot>();
  (tactics ?? []).forEach((row: ClubTactic) => tacticMap.set(row.club_id, {
    mentality: row.mentality ?? 'balanced',
    formation: row.formation ?? 'f442',
    pressIntensity: row.press_intensity ?? 50,
    tempo: row.tempo ?? 50,
    defensiveLine: row.defensive_line ?? 50,
    offsideTrap: row.offside_trap ?? false,
    timeWasting: row.time_wasting ?? false,
    freeKickTakerId: row.free_kick_taker_id ?? null,
    cornerTakerId: row.corner_taker_id ?? null,
  }));
  const homeTactic = tacticMap.get(matchRow.home_club_id) ?? { ...DEFAULT_TACTIC };
  const awayTactic = tacticMap.get(matchRow.away_club_id) ?? { ...DEFAULT_TACTIC };

  const allPlayers: PlayerRow[] = playerRows ?? [];
  const homeClubPlayers = allPlayers.filter((p) => p.club_id === matchRow.home_club_id);
  const awayClubPlayers = allPlayers.filter((p) => p.club_id === matchRow.away_club_id);
  const homePlayers = homeClubPlayers.filter((p) => p.injury_duration_weeks <= 0 && !p.is_suspended);
  const awayPlayers = awayClubPlayers.filter((p) => p.injury_duration_weeks <= 0 && !p.is_suspended);

  const { homeXG, awayXG, homePossession, pressIntensityAvg } = makeExpectedGoals(homePlayers, awayPlayers, homeTactic, awayTactic);
  const homeScore = rollGoals(homeXG);
  const awayScore = rollGoals(awayXG);
  // High-press matches are more physical - a small extra bump to injury
  // risk on top of the existing scoreline-driven intensity.
  const pressPhysicality = Math.max(0, normalizedDelta(pressIntensityAvg)) * 0.15;
  const matchIntensity = Math.min(1.4, 0.35 + (homeScore + awayScore) * 0.12 + Math.abs(homeScore - awayScore) * 0.08 + pressPhysicality);

  const { error: updateError, data: updatedRows } = await supabase
    .from('matches')
    .update({ home_score: homeScore, away_score: awayScore, is_played: true })
    .eq('id', matchRow.id)
    .eq('is_played', false)
    .select('id');

  if (updateError) throw new Error(`Maç güncellenirken hata oluştu: ${updateError.message}`);
  if (!updatedRows || updatedRows.length === 0) {
    // Someone else (the other trigger path) already resolved this match
    // between our SELECT and UPDATE - not an error, just a no-op.
    return { alreadyPlayed: true };
  }

  const timelineEvents: Array<Record<string, unknown>> = [];

  for (let idx = 0; idx < homeScore; idx += 1) {
    const scorer = choosePlayer(homePlayers);
    const assist = scorer ? choosePlayer(homePlayers.filter((player) => player.id !== scorer.id)) : null;
    timelineEvents.push(createEvent(
      matchRow.id, randomBetween(1, 90), 'goal', matchRow.home_club_id, scorer?.id ?? null, assist?.id ?? null,
      scorer ? `${scorer.name} gol attı${assist ? `, asist: ${assist.name}` : ''}` : 'Ev sahibi takım gol attı.',
    ));
  }

  for (let idx = 0; idx < awayScore; idx += 1) {
    const scorer = choosePlayer(awayPlayers);
    const assist = scorer ? choosePlayer(awayPlayers.filter((player) => player.id !== scorer.id)) : null;
    timelineEvents.push(createEvent(
      matchRow.id, randomBetween(1, 90), 'goal', matchRow.away_club_id, scorer?.id ?? null, assist?.id ?? null,
      scorer ? `${scorer.name} gol attı${assist ? `, asist: ${assist.name}` : ''}` : 'Deplasman takımı gol attı.',
    ));
  }

  if (Math.random() < 0.35) {
    const side = Math.random() < 0.5 ? 'home' : 'away';
    const teamPlayers = side === 'home' ? homePlayers : awayPlayers;
    const player = choosePlayer(teamPlayers);
    if (player) {
      timelineEvents.push(createEvent(
        matchRow.id, randomBetween(10, 85), 'penalty',
        side === 'home' ? matchRow.home_club_id : matchRow.away_club_id, player.id, null,
        `${player.name} penaltı kazandı veya kullandı.`,
      ));
    }
  }

  // High-press matches draw more fouls and cards; passive matches fewer.
  const cardProbability = Math.min(0.85, Math.max(0.35, 0.6 + normalizedDelta(pressIntensityAvg) * 0.15));
  if (Math.random() < cardProbability) {
    const cardCount = Math.max(1, Math.min(2, Math.floor(Math.random() * 3)));
    for (let idx = 0; idx < cardCount; idx += 1) {
      const side = Math.random() < 0.5 ? 'home' : 'away';
      const teamPlayers = side === 'home' ? homePlayers : awayPlayers;
      const player = choosePlayer(teamPlayers);
      if (player) {
        const cardType = Math.random() < 0.18 ? 'red_card' : 'yellow_card';
        timelineEvents.push(createEvent(
          matchRow.id, randomBetween(10, 85), cardType,
          side === 'home' ? matchRow.home_club_id : matchRow.away_club_id, player.id, null,
          `${player.name} ${cardType === 'red_card' ? 'kırmızı kart gördü' : 'sarı kart gördü'}.`,
        ));
      }
    }
  }

  for (const player of [...homeClubPlayers, ...awayClubPlayers]) {
    const injury = applyInjury(player, matchIntensity);
    if (!injury) continue;
    const nextFitness = Math.max(35, player.fitness - Math.round(injury.duration * 3 + matchIntensity * 6));
    const nextMorale = Math.max(40, player.morale - Math.round(injury.duration * 2));
    await supabase.from('players').update({
      injury_duration_weeks: injury.duration,
      injury_type: injury.injuryType,
      is_suspended: true,
      fitness: nextFitness,
      morale: nextMorale,
    }).eq('id', player.id);

    timelineEvents.push(createEvent(
      matchRow.id, randomBetween(10, 75), 'injury', player.club_id, player.id, null,
      `${player.name} ${injury.injuryType} yaşadı.`,
    ));
  }

  const substitutionCount = Math.floor(Math.random() * 2);
  for (let idx = 0; idx < substitutionCount; idx += 1) {
    const side = Math.random() < 0.5 ? 'home' : 'away';
    const teamPlayers = side === 'home' ? homePlayers : awayPlayers;
    const fromPlayer = choosePlayer(teamPlayers);
    const toPlayer = choosePlayer(teamPlayers.filter((p) => p.id !== fromPlayer?.id));
    if (fromPlayer && toPlayer) {
      timelineEvents.push(createEvent(
        matchRow.id, randomBetween(55, 90), 'substitution',
        side === 'home' ? matchRow.home_club_id : matchRow.away_club_id, fromPlayer.id, toPlayer.id,
        `${fromPlayer.name} yerine ${toPlayer.name} oyuna girdi.`,
      ));
    }
  }

  const sortedEvents = timelineEvents.sort((a, b) => (a.minute as number) - (b.minute as number));
  if (sortedEvents.length > 0) {
    const { error: eventInsertError } = await supabase.from('match_events').insert(sortedEvents);
    if (eventInsertError) throw new Error(`Maç olayları kaydedilemedi: ${eventInsertError.message}`);
  }

  const homeEconomy = computeClubEconomy(homeClub, homeClubPlayers, true, homeScore, awayScore);
  const awayEconomy = computeClubEconomy(awayClub, awayClubPlayers, false, awayScore, homeScore);

  for (const economy of [homeEconomy, awayEconomy]) {
    const { error: clubUpdateError } = await supabase
      .from('clubs')
      .update({ budget: economy.newBudget })
      .eq('id', economy.clubId);
    if (clubUpdateError) throw new Error(`Kulüp bütçesi güncellenirken hata oluştu: ${clubUpdateError.message}`);

    const summaryText = `Maç sonucu ${economy.goalsFor}-${economy.goalsAgainst}. Gelir: Stadyum +${economy.stadiumRevenue} GP, Sponsor +${economy.sponsorRevenue} GP, Bonus ${economy.matchBonus} GP. Gider: Oyuncu -${economy.playerWages} GP, Bakım -${economy.maintenanceCost} GP. Net: ${economy.netIncome > 0 ? '+' : ''}${economy.netIncome} GP`;

    await supabase.from('financial_transactions').insert({
      club_id: economy.clubId,
      type: 'match_income',
      amount: economy.netIncome,
      description: summaryText,
      source: 'match_engine',
    });

    const club = economy.clubId === homeClub.id ? homeClub : awayClub;
    if (club.user_id) {
      await supabase.from('inbox_messages').insert({
        recipient_id: club.user_id,
        title: 'Maç Sonucu',
        body: summaryText,
        is_read: false,
        created_at: new Date().toISOString(),
      });
    }
  }

  const { error: standingsError } = await supabase.rpc('update_standings_after_match', { p_match_id: matchRow.id });
  if (standingsError) throw new Error(`Puan durumu güncellenirken hata oluştu: ${standingsError.message}`);

  return {
    matchId: matchRow.id,
    homeClubId: matchRow.home_club_id,
    awayClubId: matchRow.away_club_id,
    homeScore,
    awayScore,
    homeShots: Math.max(1, Math.round(homeXG * 3)),
    awayShots: Math.max(1, Math.round(awayXG * 3)),
    homeXg: Number(homeXG.toFixed(2)),
    awayXg: Number(awayXG.toFixed(2)),
    homePossession,
    commentary: [
      `Maç oynandı: ${homeScore}-${awayScore}`,
      `Ev sahibi xG: ${homeXG.toFixed(2)}, Deplasman xG: ${awayXG.toFixed(2)}`,
    ],
    events: sortedEvents,
    economy: [homeEconomy, awayEconomy],
  };
}

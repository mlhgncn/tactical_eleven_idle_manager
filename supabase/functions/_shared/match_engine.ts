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
  season_id: string;
}

export interface ClubRow {
  id: string;
  budget: number;
  stadium_capacity: number | null;
  ticket_price: number | null;
  training_facility_level: number | null;
  sponsor_level: number | null;
  user_id: string | null;
  camp_active_for_match_id?: string | null;
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
  starting_eleven_ids: string[] | null;
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
  startingElevenIds: string[] | null;
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
  startingElevenIds: null,
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

// lib/screens/squad_screen.dart'taki _formationSlots ile birebir aynı slot
// grup dizilimi (x/y koordinatları burada gerekmiyor, sadece grup sırası).
// starting_eleven_ids[i], bu dizideki slots[i].group'ta oynuyor demektir.
const FORMATION_SLOT_GROUPS: Record<string, PositionGroup[]> = {
  f433: ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'FOR', 'FOR', 'FOR'],
  f442: ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'FOR', 'FOR'],
  f352: ['GK', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'MID', 'FOR', 'FOR'],
  f532: ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'FOR', 'FOR'],
  // Diamond-midfield 4-4-2 variant - same GK/DEF/MID/FOR group counts as
  // f442, kept as a distinct formation key for the matchup matrix + UI.
  f442b: ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'FOR', 'FOR'],
  f4231: ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'MID', 'FOR'],
  f4141: ['GK', 'DEF', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'MID', 'FOR'],
};

const POSITION_GROUP_ORDER: PositionGroup[] = ['GK', 'DEF', 'MID', 'FOR'];
const POSITION_MISMATCH_PENALTIES = [0, 0.15, 0.30, 0.50];

// lib/screens/squad_screen.dart'taki effectiveAbilityInSlot ile birebir
// aynı formül: bir oyuncu kendi doğal mevki grubu dışında bir slotta
// oynatılırsa, mesafeye göre kademeli güç kaybeder.
function effectiveAbilityInSlot(player: PlayerRow, slotGroup: PositionGroup): number {
  const ownIndex = POSITION_GROUP_ORDER.indexOf(positionGroup(player.position));
  const slotIndex = POSITION_GROUP_ORDER.indexOf(slotGroup);
  if (ownIndex < 0 || slotIndex < 0) return player.current_ability;
  const distance = Math.min(Math.abs(ownIndex - slotIndex), POSITION_MISMATCH_PENALTIES.length - 1);
  return Math.round(player.current_ability * (1 - POSITION_MISMATCH_PENALTIES[distance]));
}

interface RosterEntry {
  player: PlayerRow;
  effectiveGroup: PositionGroup;
  effectiveAbility: number;
}

// Kulübün starting_eleven_ids + formation bilgisinden, sahadaki 11 kişinin
// gerçek slot atamasını ve mevki-uyuşmazlığı cezası uygulanmış efektif
// ability'sini üretir - artık kadronun tamamı değil, SADECE sahadaki 11
// kişi maça dahil oluyor, ve mevki dışı oynatılan oyuncu burada (UI'daki
// squad_screen.dart ile birebir aynı formülle) güç kaybediyor. Taktik hiç
// kaydedilmemişse eski davranışa (tüm uygun kadro, kendi doğal mevkisinde,
// cezasız) düşer. Kaydedilmiş bir XI'de sakat/cezalı/kulüpten ayrılmış biri
// varsa, o slot tek başına en iyi uygun yedekle (aynı slot grubunda,
// current_ability'ye göre en yüksek, henüz sahada olmayan) değiştirilir -
// tüm XI'yi atıp kadronun tamamına düşmek yerine.
function buildEffectiveRoster(
  clubPlayers: PlayerRow[],
  formation: string | null,
  startingElevenIds: string[] | null | undefined,
): RosterEntry[] {
  const slotGroups = FORMATION_SLOT_GROUPS[(formation ?? 'f442').toLowerCase()];
  const playerMap = new Map(clubPlayers.map((p) => [p.id, p]));
  const isAvailable = (p: PlayerRow) => p.injury_duration_weeks <= 0 && !p.is_suspended;

  if (slotGroups && startingElevenIds && startingElevenIds.length === slotGroups.length) {
    const roster: RosterEntry[] = [];
    const usedIds = new Set<string>();
    let sawKnownPlayer = false;

    for (let i = 0; i < slotGroups.length; i += 1) {
      const slotGroup = slotGroups[i];
      let player = playerMap.get(startingElevenIds[i]);
      if (player) sawKnownPlayer = true;

      if (!player || !isAvailable(player)) {
        // Best available bench replacement for this slot: same position
        // group, not already used elsewhere in this XI, highest
        // current_ability first.
        const replacement = clubPlayers
          .filter((p) => !usedIds.has(p.id) && isAvailable(p) && positionGroup(p.position) === slotGroup)
          .sort((a, b) => b.current_ability - a.current_ability)[0];
        player = replacement;
      }

      if (!player) continue;
      usedIds.add(player.id);
      roster.push({
        player,
        effectiveGroup: slotGroup,
        effectiveAbility: effectiveAbilityInSlot(player, slotGroup),
      });
    }

    if (sawKnownPlayer) return roster;
  }

  return clubPlayers
    .filter(isAvailable)
    .map((p) => ({ player: p, effectiveGroup: positionGroup(p.position), effectiveAbility: p.current_ability }));
}

// Classic rock-paper-scissors formation matchups: each entry is the attack
// modifier a formation gets when facing the given opponent formation.
const FORMATION_MATCHUPS: Record<string, Record<string, number>> = {
  f442: { f442: 0, f433: 0.04, f352: -0.03, f532: 0.02, f442b: 0.01, f4231: -0.02, f4141: 0.03 },
  f433: { f442: -0.02, f433: 0, f352: 0.02, f532: 0.05, f442b: -0.01, f4231: 0.03, f4141: -0.01 },
  f352: { f442: 0.05, f433: -0.03, f352: 0, f532: 0.01, f442b: 0.02, f4231: -0.02, f4141: 0.02 },
  f532: { f442: -0.01, f433: -0.04, f352: 0.04, f532: 0, f442b: -0.02, f4231: -0.03, f4141: 0.01 },
  // Diamond midfield: strong through the middle, a bit weaker out wide.
  f442b: { f442: -0.01, f433: 0.02, f352: -0.01, f532: 0.03, f442b: 0, f4231: 0.01, f4141: -0.02 },
  // 4-2-3-1: extra central control (double pivot), so it edges out
  // midfield-heavy shapes but struggles for width against wing-backs.
  f4231: { f442: 0.02, f433: -0.02, f352: 0.03, f532: 0.04, f442b: 0.00, f4231: 0, f4141: 0.02 },
  // 4-1-4-1: single defensive pivot, solid but unspectacular everywhere.
  f4141: { f442: -0.02, f433: 0.02, f352: -0.01, f532: -0.01, f442b: 0.03, f4231: -0.01, f4141: 0 },
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

function phaseRating(roster: RosterEntry[], group: PositionGroup): number {
  const groupEntries = roster.filter((r) => r.effectiveGroup === group);
  const pool = groupEntries.length > 0 ? groupEntries : roster;
  if (pool.length === 0) return 50;

  const statFor = (r: RosterEntry): number => {
    const p = r.player;
    const ca = r.effectiveAbility;
    switch (group) {
      case 'DEF':
        return ca * 0.5 + p.tackling * 3 + p.composure * 1.5;
      case 'MID':
        return ca * 0.5 + p.passing * 2.5 + p.determination * 1.5;
      case 'FOR':
        return ca * 0.5 + p.finishing * 3 + p.composure * 1.5;
      default:
        return ca;
    }
  };

  return pool.reduce((sum, r) => sum + statFor(r), 0) / pool.length;
}

function blendedRating(abilityRating: number, tacticalModifier: number, moraleAvg: number): number {
  const tacticalScore = 50 + tacticalModifier * 200 + (moraleAvg - 75) * 0.6;
  return abilityRating * 0.7 + tacticalScore * 0.3;
}

function makeExpectedGoals(
  homeRoster: RosterEntry[],
  awayRoster: RosterEntry[],
  homeTactic: TacticSnapshot,
  awayTactic: TacticSnapshot,
) {
  const homePlayers = homeRoster.map((r) => r.player);
  const awayPlayers = awayRoster.map((r) => r.player);

  const homeAttackAbility = phaseRating(homeRoster, 'FOR');
  const homeDefenseAbility = phaseRating(homeRoster, 'DEF');
  const homeMidAbility = phaseRating(homeRoster, 'MID');
  const awayAttackAbility = phaseRating(awayRoster, 'FOR');
  const awayDefenseAbility = phaseRating(awayRoster, 'DEF');
  const awayMidAbility = phaseRating(awayRoster, 'MID');

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

// Performance multiplier for stadium/sponsor revenue - fans turn up (and
// sponsors pay more) for a team that's actually winning. Scaled around a
// neutral 1.0 at a 50% win rate, ranging roughly 0.7x (struggling team) to
// 1.3x (dominant team), so it nudges the economy without swinging it
// wildly. formSample is how many league games the win rate is based on -
// below a small sample (new season, promoted club) we blend toward the
// neutral 1.0 instead of overreacting to 1-2 results.
function performanceMultiplier(wins: number, draws: number, played: number): number {
  if (played <= 0) return 1.0;
  const winRate = (wins + draws * 0.5) / played;
  const sampleWeight = Math.min(1, played / 5); // ramps up to full effect over the first 5 games
  const raw = 0.7 + winRate * 0.6; // winRate 0 -> 0.7x, winRate 1 -> 1.3x
  return 1.0 + (raw - 1.0) * sampleWeight;
}

function computeClubEconomy(
  club: ClubRow,
  clubPlayers: PlayerRow[],
  isHome: boolean,
  goalsFor: number,
  goalsAgainst: number,
  standing: { wins: number; draws: number; played: number } | null,
): ClubEconomyResult {
  const stadiumCapacity = Number(club.stadium_capacity ?? 15000);
  const ticketPrice = Number(club.ticket_price ?? 5);
  const trainingFacilityLevel = Number(club.training_facility_level ?? 1);
  const sponsorLevel = Number(club.sponsor_level ?? 1);
  const budget = Number(club.budget ?? 0);
  const perfMultiplier = performanceMultiplier(standing?.wins ?? 0, standing?.draws ?? 0, standing?.played ?? 0);

  const matchBonus = goalsFor > goalsAgainst ? 300 : goalsFor === goalsAgainst ? 100 : -200;
  const playerWages = clubPlayers.reduce((sum, player) => sum + player.current_ability * 2, 0);
  // Only the home club sells tickets for this fixture. Stadium + sponsor
  // revenue both scale with the club's recent league performance (see
  // performanceMultiplier) - a team on a good run fills more seats and
  // attracts better sponsor terms.
  const stadiumRevenue = isHome ? Math.round((stadiumCapacity * ticketPrice) / 8 * perfMultiplier) : 0;
  const sponsorRevenue = Math.round(sponsorLevel * 500 * perfMultiplier);
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
    .select('id,budget,stadium_capacity,ticket_price,training_facility_level,sponsor_level,user_id,camp_active_for_match_id')
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
    .select('club_id,mentality,formation,press_intensity,tempo,defensive_line,offside_trap,time_wasting,free_kick_taker_id,corner_taker_id,starting_eleven_ids')
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
    startingElevenIds: row.starting_eleven_ids ?? null,
  }));
  const homeTactic = tacticMap.get(matchRow.home_club_id) ?? { ...DEFAULT_TACTIC };
  const awayTactic = tacticMap.get(matchRow.away_club_id) ?? { ...DEFAULT_TACTIC };

  const allPlayers: PlayerRow[] = playerRows ?? [];

  // A red card is a 1-match ban - since nothing else ever clears
  // is_suspended, clear it for anyone carrying it into this match (their
  // ban has now been served) before picking today's lineup/bench.
  const suspendedIds = allPlayers.filter((p) => p.is_suspended).map((p) => p.id);
  if (suspendedIds.length > 0) {
    await supabase.from('players').update({ is_suspended: false }).in('id', suspendedIds);
    for (const p of allPlayers) {
      if (suspendedIds.includes(p.id)) p.is_suspended = false;
    }
  }

  const homeClubPlayers = allPlayers.filter((p) => p.club_id === matchRow.home_club_id);
  const awayClubPlayers = allPlayers.filter((p) => p.club_id === matchRow.away_club_id);

  // Sahadaki 11 kişinin gerçek slot ataması ve mevki-uyuşmazlığı cezası
  // uygulanmış efektif ability'si - artık kadronun tamamı değil, SADECE bu
  // 11 kişi maça dahil oluyor (bkz. buildEffectiveRoster).
  const homeRoster = buildEffectiveRoster(homeClubPlayers, homeTactic.formation, homeTactic.startingElevenIds);
  const awayRoster = buildEffectiveRoster(awayClubPlayers, awayTactic.formation, awayTactic.startingElevenIds);
  const homePlayers = homeRoster.map((r) => r.player);
  const awayPlayers = awayRoster.map((r) => r.player);
  // Yedek kulübesi: kadroda olup sahadaki 11'de (homePlayers/awayPlayers)
  // olmayan, sakat/cezalı olmayan oyuncular - oyuna giren (substitution)
  // buradan seçilmeli, sahada zaten oynayan 11 kişiden değil.
  const homeStartingIds = new Set(homePlayers.map((p) => p.id));
  const awayStartingIds = new Set(awayPlayers.map((p) => p.id));
  const homeBench = homeClubPlayers.filter((p) => !homeStartingIds.has(p.id) && p.injury_duration_weeks <= 0 && !p.is_suspended);
  const awayBench = awayClubPlayers.filter((p) => !awayStartingIds.has(p.id) && p.injury_duration_weeks <= 0 && !p.is_suspended);

  const { homeXG: baseHomeXG, awayXG: baseAwayXG, homePossession, pressIntensityAvg } = makeExpectedGoals(homeRoster, awayRoster, homeTactic, awayTactic);
  // Team Camp: a one-shot +5% performance bonus for the club's next match,
  // consumed here regardless of the match outcome.
  const homeCamped = homeClub.camp_active_for_match_id === matchRow.id;
  const awayCamped = awayClub.camp_active_for_match_id === matchRow.id;
  const homeXG = homeCamped ? baseHomeXG * 1.05 : baseHomeXG;
  const awayXG = awayCamped ? baseAwayXG * 1.05 : baseAwayXG;
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

  // Consume the one-shot camp bonus now that it has been applied above.
  if (homeCamped) {
    await supabase.from('clubs').update({ camp_active_for_match_id: null }).eq('id', homeClub.id);
  }
  if (awayCamped) {
    await supabase.from('clubs').update({ camp_active_for_match_id: null }).eq('id', awayClub.id);
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
        // Only a red card is an actual disciplinary suspension (next-match
        // ban) - this used to never fire at all, while every injury below
        // was incorrectly marking is_suspended, so injured (not suspended)
        // players displayed a "Cezalı" (suspended) label in the UI.
        if (cardType === 'red_card') {
          await supabase.from('players').update({ is_suspended: true }).eq('id', player.id);
        }
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
    const teamBench = side === 'home' ? homeBench : awayBench;
    const fromPlayer = choosePlayer(teamPlayers);
    const toPlayer = choosePlayer(teamBench);
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

  // Recent-performance standings, fetched BEFORE this match's result is
  // applied (update_standings_after_match runs later below) - so the
  // multiplier reflects form coming into this match, not including it.
  const { data: standingsRows } = await supabase
    .from('league_standings')
    .select('club_id,wins,draws,played')
    .in('club_id', clubIds)
    .eq('season_id', matchRow.season_id);
  const standingsMap = new Map<string, { wins: number; draws: number; played: number }>(
    (standingsRows ?? []).map((s: { club_id: string; wins: number; draws: number; played: number }) => [
      s.club_id,
      { wins: s.wins, draws: s.draws, played: s.played },
    ]),
  );

  const homeEconomy = computeClubEconomy(homeClub, homeClubPlayers, true, homeScore, awayScore, standingsMap.get(matchRow.home_club_id) ?? null);
  const awayEconomy = computeClubEconomy(awayClub, awayClubPlayers, false, awayScore, homeScore, standingsMap.get(matchRow.away_club_id) ?? null);

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

  // Lineup-neglect tracking: a valid saved XI (right length, all slots
  // filled by known/available players) resets the counter; anything else
  // (never set, wrong length, or fully invalidated by injuries/suspensions
  // - see buildEffectiveRoster) counts as a miss. 10 misses in a row
  // releases the whole squad to free agency (public.track_lineup_neglect).
  const slotCountForFormation = (formation: string | null) =>
    FORMATION_SLOT_GROUPS[(formation ?? 'f442').toLowerCase()]?.length ?? 11;
  const homeHadValidLineup = !!homeTactic.startingElevenIds &&
    homeTactic.startingElevenIds.length === slotCountForFormation(homeTactic.formation);
  const awayHadValidLineup = !!awayTactic.startingElevenIds &&
    awayTactic.startingElevenIds.length === slotCountForFormation(awayTactic.formation);
  await supabase.rpc('track_lineup_neglect', { p_club_id: matchRow.home_club_id, p_had_valid_lineup: homeHadValidLineup });
  await supabase.rpc('track_lineup_neglect', { p_club_id: matchRow.away_club_id, p_had_valid_lineup: awayHadValidLineup });

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

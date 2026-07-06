import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.34.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_URL veya SUPABASE_SERVICE_ROLE_KEY ortam değişkenleri tanımlı değil.');
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

interface MatchRow {
  id: string;
  home_club_id: string;
  away_club_id: string;
  match_date: string;
}

interface ClubTactic {
  club_id: string;
  mentality: string | null;
}

interface PlayerRow {
  id: string;
  club_id: string | null;
  current_ability: number;
  age: number;
  injury_proneness: number;
  fitness: number;
  morale: number;
  injury_duration_weeks: number;
  is_suspended: boolean;
  injury_type: string | null;
}

function mentalityModifier(mentality: string | null): number {
  switch (mentality?.toLowerCase()) {
    case 'attacking':
      return 0.12;
    case 'defensive':
      return -0.08;
    case 'balanced':
    default:
      return 0;
  }
}

function makeExpectedGoals(
  homeStrength: number,
  awayStrength: number,
  homeMentality: string | null,
  awayMentality: string | null,
) {
  const homeEnergy = 0.95 + mentalityModifier(homeMentality);
  const awayEnergy = 0.90 + mentalityModifier(awayMentality);
  const strengthDiff = (homeStrength - awayStrength) / 20;

  const homeXG = Math.max(0.3, 1.0 + homeStrength * 0.02 + strengthDiff + homeEnergy * 0.15);
  const awayXG = Math.max(0.3, 0.9 + awayStrength * 0.02 - strengthDiff + awayEnergy * 0.12);

  return {
    homeXG,
    awayXG,
  };
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

function getAvailablePlayers(players: PlayerRow[]): PlayerRow[] {
  return players.filter((player) => player.injury_duration_weeks <= 0 && !player.is_suspended);
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

function createResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return createResponse({ error: 'Sadece POST istekleri desteklenir.' }, 405);
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return createResponse({ error: 'Kimlik doğrulaması gerekli.' }, 401);
    }

    const jwt = authHeader.split(' ')[1];
    const { data: { user }, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !user) {
      return createResponse({ error: 'Geçersiz kullanıcı oturumu.' }, 401);
    }

    const { data: club, error: clubError } = await supabase
      .from('clubs')
      .select('id,budget,stadium_capacity,ticket_price,training_facility_level,sponsor_level')
      .eq('user_id', user.id)
      .maybeSingle();

    if (clubError) {
      return createResponse({ error: 'Kulüp bilgisi alınamadı.' }, 500);
    }
    if (!club || !club.id) {
      return createResponse({ message: 'Oynanacak maç için kulüp bulunamadı.' }, 200);
    }

    const clubId = club.id as string;
    const clubBudget = Number(club.budget ?? 0);
    const stadiumCapacity = Number(club.stadium_capacity ?? 15000);
    const ticketPrice = Number(club.ticket_price ?? 5);
    const trainingFacilityLevel = Number(club.training_facility_level ?? 1);
    const sponsorLevel = Number(club.sponsor_level ?? 1);

    const { data: matchRow, error: matchError } = await supabase
      .from<MatchRow>('matches')
      .select('id,home_club_id,away_club_id,match_date')
      .or(`home_club_id.eq.${clubId},away_club_id.eq.${clubId}`)
      .eq('is_played', false)
      .order('match_date', { ascending: true })
      .limit(1)
      .maybeSingle();

    if (matchError) {
      return createResponse({ error: `Maç sorgulanırken hata oluştu: ${matchError.message}` }, 500);
    }

    if (!matchRow) {
      return createResponse({ message: 'Oynanacak gelecek maç bulunamadı.' }, 200);
    }

    const clubIds = [matchRow.home_club_id, matchRow.away_club_id];
    const { data: playerRows, error: playerError } = await supabase
      .from<PlayerRow>('players')
      .select('id,club_id,current_ability,age,injury_proneness,fitness,morale,injury_duration_weeks,is_suspended,injury_type')
      .in('club_id', clubIds);

    if (playerError) {
      return createResponse({ error: `Oyuncu verileri alınamadı: ${playerError.message}` }, 500);
    }

    const { data: tactics, error: tacticsError } = await supabase
      .from<ClubTactic>('tactics')
      .select('club_id,mentality')
      .in('club_id', clubIds);

    if (tacticsError) {
      return createResponse({ error: `Taktikler okunamadı: ${tacticsError.message}` }, 500);
    }

    const strengthMap = new Map<string, { total: number; count: number }>();
    const availablePlayers = getAvailablePlayers(playerRows ?? []);
    availablePlayers.forEach((player) => {
      if (!player.club_id) return;
      const current = strengthMap.get(player.club_id) ?? { total: 0, count: 0 };
      current.total += player.current_ability;
      current.count += 1;
      strengthMap.set(player.club_id, current);
    });

    const clubStrength = new Map<string, number>();
    clubIds.forEach((id) => {
      const entry = strengthMap.get(id);
      const avg = entry?.count ? entry.total / entry.count : 50;
      clubStrength.set(id, avg);
    });

    const tacticMap = new Map<string, string | null>();
    tactics?.forEach((row) => tacticMap.set(row.club_id, row.mentality ?? 'balanced'));

    const homeStrength = clubStrength.get(matchRow.home_club_id) ?? 50;
    const awayStrength = clubStrength.get(matchRow.away_club_id) ?? 50;
    const homeMentality = tacticMap.get(matchRow.home_club_id) ?? 'balanced';
    const awayMentality = tacticMap.get(matchRow.away_club_id) ?? 'balanced';

    const { homeXG, awayXG } = makeExpectedGoals(homeStrength, awayStrength, homeMentality, awayMentality);
    const homeScore = rollGoals(homeXG);
    const awayScore = rollGoals(awayXG);
    const matchIntensity = Math.min(1.4, 0.35 + (homeScore + awayScore) * 0.12 + Math.abs(homeScore - awayScore) * 0.08);

    const { error: updateError } = await supabase
      .from('matches')
      .update({ home_score: homeScore, away_score: awayScore, is_played: true })
      .eq('id', matchRow.id)
      .eq('is_played', false);

    if (updateError) {
      return createResponse({ error: `Maç güncellenirken hata oluştu: ${updateError.message}` }, 500);
    }

    const clubPlayers = (playerRows ?? []).filter((player) => player.club_id === clubId);
    const homePlayers = (playerRows ?? []).filter(
      (player) => player.club_id === matchRow.home_club_id && player.injury_duration_weeks <= 0 && !player.is_suspended,
    );
    const awayPlayers = (playerRows ?? []).filter(
      (player) => player.club_id === matchRow.away_club_id && player.injury_duration_weeks <= 0 && !player.is_suspended,
    );
    const timelineEvents: Array<Record<string, unknown>> = [];

    for (let idx = 0; idx < homeScore; idx += 1) {
      const scorer = choosePlayer(homePlayers);
      const assist = scorer ? choosePlayer(homePlayers.filter((player) => player.id !== scorer.id)) : null;
      timelineEvents.push(createEvent(
        matchRow.id,
        randomBetween(1, 90),
        'goal',
        matchRow.home_club_id,
        scorer?.id ?? null,
        assist?.id ?? null,
        scorer
          ? `${scorer.id} gol attı${assist ? `, asist: ${assist.id}` : ''}`
          : 'Ev sahibi takım gol attı.',
      ));
    }

    for (let idx = 0; idx < awayScore; idx += 1) {
      const scorer = choosePlayer(awayPlayers);
      const assist = scorer ? choosePlayer(awayPlayers.filter((player) => player.id !== scorer.id)) : null;
      timelineEvents.push(createEvent(
        matchRow.id,
        randomBetween(1, 90),
        'goal',
        matchRow.away_club_id,
        scorer?.id ?? null,
        assist?.id ?? null,
        scorer
          ? `${scorer.id} gol attı${assist ? `, asist: ${assist.id}` : ''}`
          : 'Deplasman takımı gol attı.',
      ));
    }

    if (Math.random() < 0.35) {
      const side = Math.random() < 0.5 ? 'home' : 'away';
      const teamPlayers = side === 'home' ? homePlayers : awayPlayers;
      const player = choosePlayer(teamPlayers);
      if (player) {
        timelineEvents.push(createEvent(
          matchRow.id,
          randomBetween(10, 85),
          'penalty',
          side === 'home' ? matchRow.home_club_id : matchRow.away_club_id,
          player.id,
          null,
          `${player.id} penaltı kazandı veya kullandı.`,
        ));
      }
    }

    if (Math.random() < 0.6) {
      const cardCount = Math.max(1, Math.min(2, Math.floor(Math.random() * 3)));
      for (let idx = 0; idx < cardCount; idx += 1) {
        const side = Math.random() < 0.5 ? 'home' : 'away';
        const teamPlayers = side === 'home' ? homePlayers : awayPlayers;
        const player = choosePlayer(teamPlayers);
        if (player) {
          const cardType = Math.random() < 0.18 ? 'red_card' : 'yellow_card';
          timelineEvents.push(createEvent(
            matchRow.id,
            randomBetween(10, 85),
            cardType,
            side === 'home' ? matchRow.home_club_id : matchRow.away_club_id,
            player.id,
            null,
            `${player.id} ${cardType === 'red_card' ? 'kırmızı kart gördü' : 'sarı kart gördü'}.`,
          ));
        }
      }
    }

    const injuryUpdates: Array<{ player: PlayerRow; injuryType: string; duration: number }> = [];
    for (const player of (playerRows ?? [])) {
      if (player.club_id !== matchRow.home_club_id && player.club_id !== matchRow.away_club_id) {
        continue;
      }
      const injury = applyInjury(player, matchIntensity);
      if (!injury) continue;
      injuryUpdates.push({ player, injuryType: injury.injuryType, duration: injury.duration });
    }

    for (const injured of injuryUpdates) {
      const nextFitness = Math.max(35, injured.player.fitness - Math.round(injured.duration * 3 + matchIntensity * 6));
      const nextMorale = Math.max(40, injured.player.morale - Math.round(injured.duration * 2));
      await supabase
        .from('players')
        .update({
          injury_duration_weeks: injured.duration,
          injury_type: injured.injuryType,
          is_suspended: true,
          fitness: nextFitness,
          morale: nextMorale,
        })
        .eq('id', injured.player.id);

      timelineEvents.push(createEvent(
        matchRow.id,
        randomBetween(10, 75),
        'injury',
        injured.player.club_id,
        injured.player.id,
        null,
        `${injured.player.id} ${injured.injuryType} yaşadı.`,
      ));
    }

    const substitutionCount = Math.floor(Math.random() * 2);
    for (let idx = 0; idx < substitutionCount; idx += 1) {
      const side = Math.random() < 0.5 ? 'home' : 'away';
      const teamPlayers = side === 'home' ? homePlayers : awayPlayers;
      const fromPlayer = choosePlayer(teamPlayers);
      const toPlayer = choosePlayer(teamPlayers.filter((p) => p.id !== fromPlayer?.id));
      if (fromPlayer && toPlayer) {
        timelineEvents.push(
          createEvent(
            matchRow.id,
            randomBetween(55, 90),
            'substitution',
            side === 'home' ? matchRow.home_club_id : matchRow.away_club_id,
            fromPlayer.id,
            toPlayer.id,
            `${fromPlayer.id} yerine ${toPlayer.id} oyuna girdi.`,
          ),
        );
      }
    }

    const sortedEvents = timelineEvents.sort((a, b) => (a.minute as number) - (b.minute as number));
    const { error: eventInsertError } = await supabase.from('match_events').insert(sortedEvents);
    if (eventInsertError) {
      return createResponse({ error: `Maç olayları kaydedilemedi: ${eventInsertError.message}` }, 500);
    }

    const userIsHome = matchRow.home_club_id === clubId;
    const userGoals = userIsHome ? homeScore : awayScore;
    const opponentGoals = userIsHome ? awayScore : homeScore;
    const matchBonus = userGoals > opponentGoals ? 300 : userGoals == opponentGoals ? 100 : -200;

    const playerWages = clubPlayers.reduce((sum, player) => sum + player.current_ability * 2, 0);
    const stadiumRevenue = Math.floor((stadiumCapacity * ticketPrice) / 3);
    const sponsorRevenue = sponsorLevel * 500;
    const maintenanceCost = Math.floor(stadiumCapacity / 200) + trainingFacilityLevel * 25;
    const totalRevenue = stadiumRevenue + sponsorRevenue + matchBonus;
    const totalExpense = playerWages + maintenanceCost;
    const netIncome = totalRevenue - totalExpense;

    const { error: clubUpdateError } = await supabase
      .from('clubs')
      .update({
        budget: clubBudget + netIncome,
      })
      .eq('id', clubId);

    if (clubUpdateError) {
      return createResponse({ error: `Kulüp bütçesi güncellenirken hata oluştu: ${clubUpdateError.message}` }, 500);
    }

    const summaryText = `Maç sonucu ${homeScore}-${awayScore}. Gelir: Stadyum +${stadiumRevenue} GP, Sponsor +${sponsorRevenue} GP, Bonus ${matchBonus} GP. Gider: Oyuncu -${playerWages} GP, Bakım -${maintenanceCost} GP. Net: ${netIncome > 0 ? '+' : ''}${netIncome} GP`;

    const { error: transactionInsertError } = await supabase.from('financial_transactions').insert({
      club_id: clubId,
      type: 'match_income',
      amount: netIncome,
      description: summaryText,
      source: 'play_next_fixture',
    });

    if (transactionInsertError) {
      return createResponse({ error: `Finans işlemi kaydedilemedi: ${transactionInsertError.message}` }, 500);
    }

    await supabase.from('inbox_messages').insert({
      recipient_id: user.id,
      title: 'Maç Sonucu',
      body: summaryText,
      is_read: false,
      created_at: new Date().toISOString(),
    });

    await supabase.rpc('update_standings_after_match', { p_match_id: matchRow.id });

    const commentary = [
      `Maç oynandı: ${homeScore}-${awayScore}`,
      `Ev sahibi xG: ${homeXG.toFixed(2)}, Deplasman xG: ${awayXG.toFixed(2)}`,
    ];

    return createResponse({
      message: 'Maç başarıyla oynandı.',
      result: {
        match_id: matchRow.id,
        home_team_id: matchRow.home_club_id,
        away_team_id: matchRow.away_club_id,
        home_score: homeScore,
        away_score: awayScore,
        home_shots: Math.max(1, Math.round(homeXG * 3)),
        away_shots: Math.max(1, Math.round(awayXG * 3)),
        home_xg: Number(homeXG.toFixed(2)),
        away_xg: Number(awayXG.toFixed(2)),
        home_possession: Math.round((homeStrength / (homeStrength + awayStrength)) * 100),
        commentary,
        events: sortedEvents,
      },
      match_date: matchRow.match_date,
      income: {
        stadiumRevenue,
        sponsorRevenue,
        matchBonus,
        playerWages,
        maintenanceCost,
        netIncome,
      },
      summary: summaryText,
    });
  } catch (error) {
    return createResponse({ error: `Beklenmeyen hata: ${String(error)}` }, 500);
  }
});

import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.34.0';

// Production match results are calculated server-side in this function.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const MATCH_DATE_COLUMN = 'match_date';
const INJURY_TYPES = ['diz sakatlığı', 'kas yırtığı', 'bilek burkulması', 'sırt sakatlığı'];

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_URL veya SUPABASE_SERVICE_ROLE_KEY ortam değişkenleri tanımlı değil.');
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

interface MatchRow {
  id: string;
  home_club_id: string;
  away_club_id: string;
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

  const injuryType = INJURY_TYPES[Math.floor(Math.random() * INJURY_TYPES.length)] ?? 'sakatlık';
  const duration = Math.max(1, Math.min(6, Math.round(1 + player.age / 24 + player.injury_proneness / 12 + matchIntensity)));

  return { injuryType, duration };
}

function errorResponse(message: string, status = 500) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const now = new Date();
    const startOfDay = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0, 0));
    const nextDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);

    const { data: matches, error: matchError } = await supabase
      .from<MatchRow>('matches')
      .select('id, home_club_id, away_club_id')
      .eq('is_played', false)
      .gte(MATCH_DATE_COLUMN, startOfDay.toISOString())
      .lt(MATCH_DATE_COLUMN, nextDay.toISOString());

    if (matchError) {
      return errorResponse(`Maç sorgulanırken hata oluştu: ${matchError.message}`);
    }

    if (!matches || matches.length === 0) {
      return new Response(JSON.stringify({ message: 'Bugün oynanacak maç yok.' }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    }

    const clubIds = Array.from(new Set(matches.flatMap((match) => [match.home_club_id, match.away_club_id])));

    const { data: playerRows, error: abilitiesError } = await supabase
      .from<PlayerRow>('players')
      .select('id, club_id, current_ability, age, injury_proneness, fitness, morale, injury_duration_weeks, is_suspended, injury_type')
      .in('club_id', clubIds);

    if (abilitiesError) {
      return errorResponse(`Oyuncu yetenekleri okunamadı: ${abilitiesError.message}`);
    }

    const { data: tactics, error: tacticsError } = await supabase
      .from<ClubTactic>('tactics')
      .select('club_id, mentality')
      .in('club_id', clubIds);

    if (tacticsError) {
      return errorResponse(`Taktik bilgileri alınamadı: ${tacticsError.message}`);
    }

    const strengthMap = new Map<string, { total: number; count: number }>();
    const availablePlayers = getAvailablePlayers(playerRows ?? []);

    availablePlayers.forEach((row) => {
      if (!row.club_id) {
        return;
      }
      const current = strengthMap.get(row.club_id) ?? { total: 0, count: 0 };
      current.total += row.current_ability;
      current.count += 1;
      strengthMap.set(row.club_id, current);
    });

    const clubStrength = new Map<string, number>();
    clubIds.forEach((id) => {
      const entry = strengthMap.get(id);
      const avg = entry?.count ? entry.total / entry.count : 50;
      clubStrength.set(id, avg);
    });

    const tacticMap = new Map<string, string | null>();
    tactics?.forEach((row) => tacticMap.set(row.club_id, row.mentality ?? 'balanced'));

    const results = [];

    for (const match of matches) {
      const homeStrength = clubStrength.get(match.home_club_id) ?? 50;
      const awayStrength = clubStrength.get(match.away_club_id) ?? 50;
      const homeMentality = tacticMap.get(match.home_club_id) ?? 'balanced';
      const awayMentality = tacticMap.get(match.away_club_id) ?? 'balanced';

      const { homeXG, awayXG } = makeExpectedGoals(homeStrength, awayStrength, homeMentality, awayMentality);
      const homeScore = rollGoals(homeXG);
      const awayScore = rollGoals(awayXG);
      const matchIntensity = Math.min(1.4, 0.35 + (homeScore + awayScore) * 0.12 + Math.abs(homeScore - awayScore) * 0.08);

      const { error: updateError } = await supabase
        .from('matches')
        .update({ home_score: homeScore, away_score: awayScore, is_played: true })
        .eq('id', match.id)
        .eq('is_played', false);

      if (updateError) {
        return errorResponse(`Maç güncellemesi sırasında hata: ${updateError.message}`);
      }

      const clubPlayers = (playerRows ?? []).filter((player) => player.club_id === match.home_club_id || player.club_id === match.away_club_id);
      for (const player of clubPlayers) {
        const injury = applyInjury(player, matchIntensity);
        if (!injury) {
          continue;
        }

        const nextFitness = Math.max(35, player.fitness - Math.round(injury.duration * 3 + matchIntensity * 6));
        const nextMorale = Math.max(40, player.morale - Math.round(injury.duration * 2));
        const { error: injuryError } = await supabase
          .from('players')
          .update({
            injury_duration_weeks: injury.duration,
            injury_type: injury.injuryType,
            is_suspended: true,
            fitness: nextFitness,
            morale: nextMorale,
          })
          .eq('id', player.id);

        if (injuryError) {
          console.error(`Sakatlık güncellenemedi: ${player.id}`, injuryError.message);
        }
      }

      results.push({ match_id: match.id, home_score: homeScore, away_score: awayScore });
    }

    return new Response(JSON.stringify({ message: 'Maçlar simüle edildi.', results }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  } catch (error) {
    return errorResponse(`Beklenmeyen hata: ${String(error)}`);
  }
});

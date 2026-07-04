import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.34.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const MATCH_DATE_COLUMN = 'match_date';

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

interface ClubStrength {
  club_id: string;
  avg_ability: number;
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
    const today = new Date().toISOString().slice(0, 10);

    const { data: matches, error: matchError } = await supabase
      .from<MatchRow>('matches')
      .select('id, home_club_id, away_club_id')
      .eq('is_played', false)
      .eq(MATCH_DATE_COLUMN, today);

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

    const { data: playerAbilities, error: abilitiesError } = await supabase
      .from<{ club_id: string; current_ability: number }>('players')
      .select('club_id, current_ability')
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

    playerAbilities?.forEach((row) => {
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

      const { error: updateError } = await supabase
        .from('matches')
        .update({ home_score: homeScore, away_score: awayScore, is_played: true })
        .eq('id', match.id);

      if (updateError) {
        return errorResponse(`Maç güncellemesi sırasında hata: ${updateError.message}`);
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

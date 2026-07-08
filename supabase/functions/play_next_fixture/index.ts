import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.34.0';
import { resolveMatch } from '../_shared/match_engine.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_URL veya SUPABASE_SERVICE_ROLE_KEY ortam değişkenleri tanımlı değil.');
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

function createResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

// Interactive, single-match resolution triggered by the owning user tapping
// "Maçı Oyna" in the app. Only plays that user's own next unplayed fixture -
// due matches the user hasn't gotten to yet are also picked up by the
// scheduled auto_resolve_matches cron regardless, so tapping this early is
// just a convenience, not the only way the match gets played.
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
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (clubError) {
      return createResponse({ error: 'Kulüp bilgisi alınamadı.' }, 500);
    }
    if (!club || !club.id) {
      return createResponse({ message: 'Oynanacak maç için kulüp bulunamadı.' }, 200);
    }

    const clubId = club.id as string;

    const { data: matchRow, error: matchError } = await supabase
      .from('matches')
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

    const resolved = await resolveMatch(supabase, matchRow);
    if ('alreadyPlayed' in resolved) {
      return createResponse({ message: 'Bu maç zaten oynandı (muhtemelen zamanlanmış çözümleme tarafından).' }, 200);
    }

    const userEconomy = resolved.economy.find((e) => e.clubId === clubId) ?? resolved.economy[0];

    return createResponse({
      message: 'Maç başarıyla oynandı.',
      result: {
        match_id: resolved.matchId,
        home_team_id: resolved.homeClubId,
        away_team_id: resolved.awayClubId,
        home_score: resolved.homeScore,
        away_score: resolved.awayScore,
        home_shots: resolved.homeShots,
        away_shots: resolved.awayShots,
        home_xg: resolved.homeXg,
        away_xg: resolved.awayXg,
        home_possession: resolved.homePossession,
        commentary: resolved.commentary,
        events: resolved.events,
      },
      match_date: matchRow.match_date,
      income: {
        stadiumRevenue: userEconomy.stadiumRevenue,
        sponsorRevenue: userEconomy.sponsorRevenue,
        matchBonus: userEconomy.matchBonus,
        playerWages: userEconomy.playerWages,
        maintenanceCost: userEconomy.maintenanceCost,
        netIncome: userEconomy.netIncome,
      },
      summary: `Maç sonucu ${userEconomy.goalsFor}-${userEconomy.goalsAgainst}. Net: ${userEconomy.netIncome > 0 ? '+' : ''}${userEconomy.netIncome} GP`,
    });
  } catch (error) {
    return createResponse({ error: `Beklenmeyen hata: ${String(error)}` }, 500);
  }
});

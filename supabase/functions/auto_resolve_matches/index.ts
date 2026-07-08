import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.34.0';
import { resolveMatch, type MatchRow } from '../_shared/match_engine.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_URL veya SUPABASE_SERVICE_ROLE_KEY ortam değişkenleri tanımlı değil.');
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

// Caps how many matches one invocation resolves. Each match takes several
// sequential DB round-trips, and pg_cron's net.http_post has its own
// timeout (30s) - a large backlog (e.g. after downtime, or the initial
// fixture bootstrap) drains over several 5-minute ticks instead of one
// invocation trying to do it all and timing out before pg_net ever sees a
// response.
const BATCH_LIMIT = 15;

function createResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

// The OSM-style scheduled resolver: pg_cron calls this every few minutes.
// It has no user session (no one has to be online) - it just plays every
// match whose kickoff time has passed, for real clubs and unclaimed "bot"
// clubs alike (bot clubs simply fall back to the balanced/f442 tactics
// default inside resolveMatch). Auth is a shared secret, not a user JWT,
// since pg_cron has no user context to hand over.
serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return createResponse({ error: 'Sadece POST istekleri desteklenir.' }, 405);
  }

  const providedSecret = req.headers.get('x-cron-secret');
  if (!providedSecret) {
    return createResponse({ error: 'Yetkisiz istek.' }, 401);
  }

  const { data: secretRow, error: secretError } = await supabase
    .from('environment_secrets')
    .select('value')
    .eq('key', 'CRON_SHARED_SECRET')
    .maybeSingle();

  if (secretError || !secretRow || secretRow.value !== providedSecret) {
    return createResponse({ error: 'Yetkisiz istek.' }, 401);
  }

  try {
    const { data: dueMatches, error: matchesError } = await supabase
      .from('matches')
      .select('id,home_club_id,away_club_id,match_date')
      .eq('is_played', false)
      .lte('match_date', new Date().toISOString())
      .order('match_date', { ascending: true })
      .limit(BATCH_LIMIT);

    if (matchesError) {
      return createResponse({ error: `Maçlar sorgulanırken hata oluştu: ${matchesError.message}` }, 500);
    }

    const results: Array<{ matchId: string; status: string }> = [];

    for (const matchRow of (dueMatches ?? []) as MatchRow[]) {
      try {
        const resolved = await resolveMatch(supabase, matchRow);
        results.push({
          matchId: matchRow.id,
          status: 'alreadyPlayed' in resolved ? 'skipped_already_played' : 'resolved',
        });
      } catch (error) {
        results.push({ matchId: matchRow.id, status: `error: ${String(error)}` });
      }
    }

    return createResponse({
      message: `${results.filter((r) => r.status === 'resolved').length} maç çözümlendi.`,
      totalDue: (dueMatches ?? []).length,
      results,
    });
  } catch (error) {
    return createResponse({ error: `Beklenmeyen hata: ${String(error)}` }, 500);
  }
});

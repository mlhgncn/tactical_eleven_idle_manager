import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.34.0';

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
      .select('id, budget, sponsor_level, last_activity_at')
      .eq('user_id', user.id)
      .maybeSingle();

    if (clubError) {
      return createResponse({ error: 'Kulüp bilgisi alınamadı.' }, 500);
    }

    if (!club) {
      return createResponse({
        matchesSimulated: 0,
        totalIncome: 0,
        playersImproved: 0,
        transferOffersReceived: 0,
        inboxMessagesAdded: 0,
        offlineDurationMinutes: 0,
        summary: 'Kulüp bulunamadığı için offline ilerleme işlenmedi.',
      });
    }

    const now = new Date();
    const lastActivity = club.last_activity_at ? new Date(club.last_activity_at) : new Date(now.getTime() - 60 * 60 * 1000);
    const offlineDurationMinutes = Math.max(0, Math.floor((now.getTime() - lastActivity.getTime()) / 60000));
    const cappedMinutes = Math.min(offlineDurationMinutes, 24 * 60 * 3);

    // A minimum threshold, not just >0: without it, rapidly
    // force-quitting/reopening the app (once a minute is enough) would each
    // time grant at least one "match" of income, since matchesSimulated
    // below was floored to a minimum of 1 regardless of how little time
    // had actually passed.
    if (cappedMinutes < 5) {
      await supabase.from('clubs').update({ last_activity_at: now.toISOString() }).eq('id', club.id);
      return createResponse({
        matchesSimulated: 0,
        totalIncome: 0,
        playersImproved: 0,
        transferOffersReceived: 0,
        inboxMessagesAdded: 0,
        offlineDurationMinutes,
        summary: 'Offline ilerleme için yeterli süre yok.',
      });
    }

    // Fractional weeks, not floored-with-a-forced-minimum-of-1: the previous
    // Math.max(1, ...) meant *any* offline period, even five minutes,
    // knocked a full week off every injured player's recovery timer -
    // repeatedly reopening the app would clear all injuries almost
    // instantly. Math.ceil on the remainder preserves integer week storage
    // while only actually decrementing once a full week has really elapsed.
    const weeksElapsed = cappedMinutes / (7 * 24 * 60);
    const { data: injuredPlayers, error: injuredError } = await supabase
      .from('players')
      .select('id, injury_duration_weeks, is_suspended')
      .gt('injury_duration_weeks', 0);

    if (!injuredError && injuredPlayers) {
      for (const player of injuredPlayers) {
        const remainingWeeks = Math.max(0, Math.ceil((player.injury_duration_weeks ?? 0) - weeksElapsed));
        await supabase
          .from('players')
          .update({
            injury_duration_weeks: remainingWeeks,
            is_suspended: remainingWeeks > 0,
          })
          .eq('id', player.id);
      }
    }

    const matchesSimulated = Math.max(1, Math.floor(cappedMinutes / 60));
    const rewardMultiplier = cappedMinutes >= 24 * 60 * 3 ? 1.0 : 1.0 + (cappedMinutes / (24 * 60 * 3)) * 0.25;
    const income = Math.floor(((club.sponsor_level ?? 1) * 500 + 3000) * (matchesSimulated * rewardMultiplier)) + matchesSimulated * 1000;

    const playersImproved = Math.random() < 0.15 ? 1 : 0;
    const transferOffersReceived = Math.random() < 0.1 ? 1 : 0;

    const { error: clubUpdateError } = await supabase.from('clubs').update({
      budget: (club.budget ?? 0) + income,
      last_activity_at: now.toISOString(),
    }).eq('id', club.id);

    if (clubUpdateError) {
      return createResponse({ error: `Kulüp bütçesi güncellenirken hata oluştu: ${clubUpdateError.message}` }, 500);
    }

    const { error: transactionInsertError } = await supabase.from('financial_transactions').insert({
      club_id: club.id,
      type: 'offline_income',
      amount: income,
      description: `Offline ilerleme geliri: +${income} GP`,
      source: 'simulate_offline_progress',
    });

    if (transactionInsertError) {
      return createResponse({ error: `Finans işlemi kaydedilemedi: ${transactionInsertError.message}` }, 500);
    }

    const inboxRows: Array<{ recipient_id: string; title: string; body: string; is_read: boolean; created_at: string }> = [];
    if (playersImproved > 0) {
      inboxRows.push({
        recipient_id: user.id,
        title: 'Oyuncu Gelişimi',
        body: 'Takımınızda bir oyuncu offline dönemde gelişim gösterdi.',
        is_read: false,
        created_at: now.toISOString(),
      });
    }

    if (transferOffersReceived > 0) {
      inboxRows.push({
        recipient_id: user.id,
        title: 'Transfer Teklifi',
        body: 'Offline süreçte bir transfer teklifi geldi.',
        is_read: false,
        created_at: now.toISOString(),
      });
    }

    if (inboxRows.length > 0) {
      inboxRows.push({
        recipient_id: user.id,
        title: 'Offline Özeti',
        body: `Offline süreçte ${matchesSimulated} maç simüle edildi, ${income} GP gelir elde edildi.`,
        is_read: false,
        created_at: now.toISOString(),
      });
    }

    if (inboxRows.length > 0) {
      await supabase.from('inbox_messages').insert(inboxRows);
    }

    return createResponse({
      matchesSimulated,
      totalIncome: income,
      playersImproved,
      transferOffersReceived,
      inboxMessagesAdded: inboxRows.length,
      offlineDurationMinutes,
      summary: `Offline süreçte ${matchesSimulated} maç simüle edildi ve ${income} GP gelir elde edildi.`,
    });
  } catch (error) {
    return createResponse({ error: String(error) }, 500);
  }
});

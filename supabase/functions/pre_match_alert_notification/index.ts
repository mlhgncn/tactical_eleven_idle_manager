import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.34.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const FCM_API_KEY = Deno.env.get('FCM_API_KEY') ?? '';

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY ortam değişkenleri tanımlı olmalıdır.');
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
const FCM_URL = 'https://fcm.googleapis.com/fcm/send';

function createResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

async function getOwnerFcmToken(clubId: string): Promise<string | null> {
  const { data: club } = await supabase.from('clubs').select('id, user_id').eq('id', clubId).maybeSingle();
  const ownerUserId = typeof club?.user_id === 'string' ? club.user_id : null;
  if (!ownerUserId) return null;

  const { data: profile } = await supabase.from('profiles').select('fcm_token').eq('id', ownerUserId).maybeSingle();
  const token = typeof profile?.fcm_token === 'string' ? profile.fcm_token : null;
  return token || null;
}

async function sendPushNotification(token: string, title: string, body: string, data: Record<string, string>) {
  if (!FCM_API_KEY) {
    console.warn('pre_match_alert_notification: FCM_API_KEY not configured');
    return;
  }

  const payload = {
    to: token,
    notification: { title, body },
    data,
    android: { priority: 'high' },
    apns: { headers: { 'apns-priority': '10' } },
  };

  const response = await fetch(FCM_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `key=${FCM_API_KEY}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    throw new Error(`FCM request failed: ${response.statusText}`);
  }
}

// Called by pg_cron (process_pre_match_alerts, every 5 minutes) once a
// match crosses the 30-minutes-to-kickoff mark. Sends a push notification
// to both sides' owners (real users only - bot clubs have no fcm_token)
// reminding them to check their lineup, and logs an inbox message as a
// fallback for users without a registered FCM token or with push
// notifications disabled at the OS level.
serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return createResponse({ error: 'Sadece POST istekleri desteklenir.' }, 405);
  }

  const providedSecret = req.headers.get('x-cron-secret');
  if (!providedSecret) {
    return createResponse({ error: 'Yetkisiz istek.' }, 401);
  }

  const { data: secretRow } = await supabase
    .from('environment_secrets')
    .select('value')
    .eq('key', 'CRON_SHARED_SECRET')
    .maybeSingle();

  if (!secretRow || secretRow.value !== providedSecret) {
    return createResponse({ error: 'Yetkisiz istek.' }, 401);
  }

  try {
    const body = await req.json();
    const matchId = body['match_id'] as string | undefined;
    const homeClubId = body['home_club_id'] as string | undefined;
    const awayClubId = body['away_club_id'] as string | undefined;

    if (!matchId || !homeClubId) {
      return createResponse({ error: 'Gerekli alanlar eksik.' }, 400);
    }

    const title = 'Kritik Maç Yaklaşıyor';
    const bodyText = 'Kritik maç 30 dakika içinde başlıyor! Kadronu son kez kontrol et.';
    const clubIds = [homeClubId, awayClubId].filter((id): id is string => !!id);

    const notifications: Promise<void>[] = [];
    let inboxCount = 0;

    for (const clubId of clubIds) {
      const { data: club } = await supabase.from('clubs').select('id, user_id').eq('id', clubId).maybeSingle();
      const ownerUserId = typeof club?.user_id === 'string' ? club.user_id : null;
      if (!ownerUserId) continue;

      await supabase.from('inbox_messages').insert({
        recipient_id: ownerUserId,
        title,
        body: bodyText,
        is_read: false,
        created_at: new Date().toISOString(),
      });
      inboxCount += 1;

      const token = await getOwnerFcmToken(clubId);
      if (token) {
        notifications.push(
          sendPushNotification(token, title, bodyText, { match_id: matchId, type: 'pre_match_alert' }),
        );
      }
    }

    if (notifications.length > 0) {
      await Promise.allSettled(notifications);
    }

    return createResponse({
      message: 'Maç öncesi uyarılar işlendi.',
      inboxCount,
      pushSentCount: notifications.length,
    });
  } catch (error) {
    console.error('pre_match_alert_notification: unexpected error', {
      error: error instanceof Error ? error.message : String(error),
    });
    return createResponse({ error: 'Bildirim gönderilemedi.' }, 500);
  }
});

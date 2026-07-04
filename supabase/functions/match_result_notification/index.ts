import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.34.0';
import { initializeApp, cert } from 'https://esm.sh/firebase-admin@11.15.0/app';
import { getMessaging } from 'https://esm.sh/firebase-admin@11.15.0/messaging';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ?? '';

if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !FIREBASE_SERVICE_ACCOUNT_JSON) {
  throw new Error('SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY ve FIREBASE_SERVICE_ACCOUNT_JSON ortam değişkenleri tanımlı olmalıdır.');
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

initializeApp({
  credential: cert(JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON)),
});

const messaging = getMessaging();

function createResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function getMatchPayload(body: unknown) {
  if (typeof body !== 'object' || body === null) return null;
  const payload = (body as Record<string, unknown>)['new'] ?? (body as Record<string, unknown>)['record'] ?? body;
  if (typeof payload !== 'object' || payload === null) return null;
  return payload as Record<string, unknown>;
}

function formatBody(teamType: 'Ev Sahibi' | 'Deplasman', homeScore: number, awayScore: number) {
  const result = homeScore > awayScore ? 'kazandınız' : homeScore < awayScore ? 'kaybettiniz' : 'berabere kaldınız';
  const scoreText = `${homeScore}-${awayScore}`;
  return `Maç sonucu: ${teamType} ${scoreText}, ${result}!`;
}

async function getOwnerFcmToken(clubId: string) {
  const { data: club, error: clubError } = await supabase
    .from('clubs')
    .select('owner_id')
    .eq('id', clubId)
    .single();

  if (clubError || !club?.owner_id) {
    throw new Error(`Kulüp sahibi bulunamadı: ${clubError?.message ?? 'owner_id yok'}`);
  }

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('fcm_token')
    .eq('id', club.owner_id as string)
    .single();

  if (profileError || !profile?.fcm_token) {
    throw new Error(`FCM token bulunamadı: ${profileError?.message ?? 'token yok'}`);
  }

  return profile.fcm_token as string;
}

async function sendPushNotification(token: string, title: string, body: string, data: Record<string, string>) {
  return await messaging.send({
    token,
    notification: { title, body },
    android: { priority: 'high' },
    apns: { headers: { 'apns-priority': '10' } },
    data,
  });
}

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return createResponse({ error: 'Sadece POST istekleri desteklenir.' }, 405);
  }

  try {
    const body = await req.json();
    const payload = getMatchPayload(body);

    if (!payload) {
      return createResponse({ error: 'Webhook payloadu okunamadı.' }, 400);
    }

    const homeScore = Number(payload['home_score']);
    const awayScore = Number(payload['away_score']);
    const homeClubId = payload['home_club_id'] as string | undefined;
    const awayClubId = payload['away_club_id'] as string | undefined;
    const matchId = payload['id'] as string | undefined;

    if (!Number.isFinite(homeScore) || !Number.isFinite(awayScore) || !homeClubId) {
      return createResponse({ error: 'Gerekli alanlar eksik veya hatalı.' }, 400);
    }

    const messages = [];
    const title = 'Maç Sonucu';

    const homeNotificationBody = formatBody('Ev Sahibi', homeScore, awayScore);
    const homeToken = await getOwnerFcmToken(homeClubId);
    messages.push(
      sendPushNotification(homeToken, title, homeNotificationBody, {
        match_id: matchId ?? '',
        team: 'home',
        home_score: String(homeScore),
        away_score: String(awayScore),
      }),
    );

    if (awayClubId) {
      const awayNotificationBody = formatBody('Deplasman', homeScore, awayScore);
      const awayToken = await getOwnerFcmToken(awayClubId);
      messages.push(
        sendPushNotification(awayToken, title, awayNotificationBody, {
          match_id: matchId ?? '',
          team: 'away',
          home_score: String(homeScore),
          away_score: String(awayScore),
        }),
      );
    }

    await Promise.all(messages);

    return createResponse({ message: 'Bildirimler başarıyla gönderildi.' });
  } catch (error) {
    console.error('Bildirim hatası:', error);
    return createResponse({ error: `Bildirim gönderilemedi: ${String(error)}` }, 500);
  }
});

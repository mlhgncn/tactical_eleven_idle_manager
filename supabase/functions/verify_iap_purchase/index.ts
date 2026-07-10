import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.34.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
// Apple "In-App Purchase Shared Secret" (App Store Connect > your app >
// General > App-Specific Shared Secret). Not set yet as of this deploy -
// until it is, this function fails closed (returns 500) rather than
// crediting diamonds without ever having verified a receipt.
const APPLE_SHARED_SECRET = Deno.env.get('APPLE_IAP_SHARED_SECRET') ?? '';

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_URL veya SUPABASE_SERVICE_ROLE_KEY ortam değişkenleri tanımlı değil.');
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const APPLE_PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const APPLE_SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

function createResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

async function verifyWithApple(receiptData: string): Promise<any> {
  const payload = {
    'receipt-data': receiptData,
    password: APPLE_SHARED_SECRET,
    'exclude-old-transactions': true,
  };

  let response = await fetch(APPLE_PRODUCTION_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  });
  let json = await response.json();

  // Apple's documented way to detect a sandbox receipt was sent to the
  // production endpoint - retry against sandbox instead of failing.
  if (json.status === 21007) {
    response = await fetch(APPLE_SANDBOX_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    });
    json = await response.json();
  }

  return json;
}

// Client sends the StoreKit receipt after a purchase completes; this
// verifies it directly with Apple (never trusting the client's own claim
// of success) before crediting diamonds, and records the Apple
// transaction_id so a retried/duplicate call can never double-credit.
serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return createResponse({ error: 'Sadece POST istekleri desteklenir.' }, 405);
  }

  if (!APPLE_SHARED_SECRET) {
    return createResponse({ error: 'IAP doğrulama henüz yapılandırılmadı (APPLE_IAP_SHARED_SECRET eksik).' }, 500);
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

    const { receiptData, productId, transactionId } = await req.json();
    if (!receiptData || !productId || !transactionId) {
      return createResponse({ error: 'Eksik parametre: receiptData, productId, transactionId gerekli.' }, 400);
    }

    const { data: existing } = await supabase
      .from('iap_transactions')
      .select('id, diamonds_credited')
      .eq('transaction_id', transactionId)
      .maybeSingle();

    if (existing) {
      return createResponse({ success: true, alreadyProcessed: true, diamondsCredited: existing.diamonds_credited });
    }

    const appleResult = await verifyWithApple(receiptData);
    if (appleResult.status !== 0) {
      return createResponse({ error: `Apple makbuz doğrulaması başarısız oldu (status: ${appleResult.status}).` }, 400);
    }

    const receiptEntries: any[] = appleResult.latest_receipt_info ?? appleResult.receipt?.in_app ?? [];
    const matched = receiptEntries.find(
      (entry) => entry.transaction_id === transactionId && entry.product_id === productId,
    );
    if (!matched) {
      return createResponse({ error: 'İşlem Apple makbuzunda bulunamadı.' }, 400);
    }

    const { data: productRow, error: productError } = await supabase
      .from('diamond_products')
      .select('diamonds')
      .eq('product_id', productId)
      .maybeSingle();

    if (productError || !productRow) {
      return createResponse({ error: 'Bilinmeyen ürün.' }, 400);
    }

    const { error: insertError } = await supabase.from('iap_transactions').insert({
      user_id: user.id,
      product_id: productId,
      transaction_id: transactionId,
      diamonds_credited: productRow.diamonds,
    });

    if (insertError) {
      // Unique constraint on transaction_id - a concurrent call already
      // processed this exact transaction. Not an error from the client's
      // point of view, just already done.
      return createResponse({ success: true, alreadyProcessed: true });
    }

    const { data: profileRow, error: profileError } = await supabase
      .from('profiles')
      .select('diamonds')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError) {
      return createResponse({ error: 'Profil bilgisi alınamadı.' }, 500);
    }

    const newBalance = (profileRow?.diamonds ?? 0) + productRow.diamonds;
    const { error: updateError } = await supabase
      .from('profiles')
      .update({ diamonds: newBalance })
      .eq('id', user.id);

    if (updateError) {
      return createResponse({ error: 'Elmas bakiyesi güncellenemedi.' }, 500);
    }

    return createResponse({ success: true, diamondsCredited: productRow.diamonds, newBalance });
  } catch (error) {
    return createResponse({ error: String(error) }, 500);
  }
});

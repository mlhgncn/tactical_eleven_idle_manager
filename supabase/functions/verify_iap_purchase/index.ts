import { serve } from 'https://deno.land/std@0.203.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.34.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

// App Store Server API credentials (App Store Connect > Users and Access >
// Integrations > In-App Purchase key). Used to build a short-lived signed
// JWT that authenticates server-to-server calls to Apple - this replaces
// the legacy /verifyReceipt flow, which only understands StoreKit1's
// base64 receipt format and rejects StoreKit2's JWS transaction signature
// with status 21002 ("malformed receipt data").
const APPLE_KEY_ID = Deno.env.get('APPLE_IAP_KEY_ID') ?? '';
const APPLE_ISSUER_ID = Deno.env.get('APPLE_IAP_ISSUER_ID') ?? '';
const APPLE_PRIVATE_KEY_PEM = Deno.env.get('APPLE_IAP_PRIVATE_KEY') ?? '';
const APPLE_BUNDLE_ID = Deno.env.get('APPLE_IAP_BUNDLE_ID') ?? 'com.melih.tacticaleleven';

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_URL veya SUPABASE_SERVICE_ROLE_KEY ortam değişkenleri tanımlı değil.');
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const APP_STORE_SERVER_API_PRODUCTION = 'https://api.storekit.itunes.apple.com';
const APP_STORE_SERVER_API_SANDBOX = 'https://api.storekit-sandbox.itunes.apple.com';

function createResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlDecode(input: string): Uint8Array {
  const padded = input.replace(/-/g, '+').replace(/_/g, '/').padEnd(input.length + ((4 - (input.length % 4)) % 4), '=');
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function standardBase64Decode(input: string): Uint8Array {
  const binary = atob(input);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function importApplePrivateKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');
  const keyBytes = standardBase64Decode(pemBody);
  return crypto.subtle.importKey(
    'pkcs8',
    keyBytes,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
}

// crypto.subtle.sign('ECDSA', ...) is specified to return the raw (r||s,
// IEEE P1363) signature format that JOSE/JWT ES256 requires - but as a
// defensive fallback (some runtimes/versions have been observed to hand
// back a DER-encoded ECDSA-Sig-Value SEQUENCE instead), detect a DER
// signature by its leading 0x30 (SEQUENCE) tag and convert it to raw r||s.
function derToRawEcdsaSignature(der: Uint8Array, componentLength = 32): Uint8Array {
  if (der[0] !== 0x30) return der; // Not DER - assume already raw.

  let offset = 2; // skip SEQUENCE tag + length byte
  if (der[1] & 0x80) {
    // Long-form length (rare for a P-256 signature, but handle it).
    offset = 2 + (der[1] & 0x7f);
  }

  function readInteger(buf: Uint8Array, pos: number): { value: Uint8Array; next: number } {
    if (buf[pos] !== 0x02) throw new Error('Beklenmeyen DER yapısı (INTEGER tag yok).');
    const len = buf[pos + 1];
    let start = pos + 2;
    let bytes = buf.slice(start, start + len);
    // DER INTEGER strips leading zero padding except when needed to keep
    // the value non-negative - strip a leading 0x00 pad byte if present.
    if (bytes.length > componentLength && bytes[0] === 0x00) {
      bytes = bytes.slice(1);
    }
    return { value: bytes, next: start + len };
  }

  const r = readInteger(der, offset);
  const s = readInteger(der, r.next);

  const raw = new Uint8Array(componentLength * 2);
  raw.set(r.value, componentLength - r.value.length);
  raw.set(s.value, componentLength * 2 - s.value.length);
  return raw;
}

// Builds the short-lived (5 minute) ES256 JWT App Store Server API calls
// require in their Authorization header - signed with the .p8 private key
// downloaded once from App Store Connect (never logged, only read from an
// env secret).
async function buildAppleJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'ES256', kid: APPLE_KEY_ID, typ: 'JWT' };
  const payload = {
    iss: APPLE_ISSUER_ID,
    iat: now,
    exp: now + 300,
    aud: 'appstoreconnect-v1',
    bid: APPLE_BUNDLE_ID,
  };

  const encodedHeader = base64UrlEncode(new TextEncoder().encode(JSON.stringify(header)));
  const encodedPayload = base64UrlEncode(new TextEncoder().encode(JSON.stringify(payload)));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const privateKey = await importApplePrivateKey(APPLE_PRIVATE_KEY_PEM);
  const rawSignature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    privateKey,
    new TextEncoder().encode(signingInput),
  );
  const signatureBytes = derToRawEcdsaSignature(new Uint8Array(rawSignature));

  return `${signingInput}.${base64UrlEncode(signatureBytes)}`;
}

// A JWS has three base64url segments (header.payload.signature) - this
// decodes only the payload. Apple's own public key already produced this
// signature when the App Store Server API returned it, and the call itself
// was authenticated with our own signed JWT, so re-verifying the
// signature here is not required to trust the payload's contents.
function decodeJwsPayload(jws: string): Record<string, unknown> {
  const parts = jws.split('.');
  if (parts.length !== 3) throw new Error('Geçersiz JWS formatı.');
  const json = new TextDecoder().decode(base64UrlDecode(parts[1]));
  return JSON.parse(json);
}

async function fetchTransactionInfo(transactionId: string, appleJwt: string): Promise<Record<string, unknown>> {
  const path = `/inApps/v1/transactions/${transactionId}`;
  let response = await fetch(`${APP_STORE_SERVER_API_PRODUCTION}${path}`, {
    headers: { Authorization: `Bearer ${appleJwt}` },
  });

  // Sandbox (TestFlight/development) transactions don't exist on the
  // production endpoint - App Store Server API returns 404, retry sandbox.
  if (response.status === 404) {
    response = await fetch(`${APP_STORE_SERVER_API_SANDBOX}${path}`, {
      headers: { Authorization: `Bearer ${appleJwt}` },
    });
  }

  if (!response.ok) {
    let bodyText = '';
    try {
      bodyText = await response.text();
    } catch (_) {
      // ignore
    }
    throw new Error(`App Store Server API isteği başarısız oldu (status: ${response.status}): ${bodyText}`);
  }

  const body = await response.json();
  const signedTransactionInfo = body.signedTransactionInfo as string | undefined;
  if (!signedTransactionInfo) {
    throw new Error('Apple yanıtında signedTransactionInfo bulunamadı.');
  }

  return decodeJwsPayload(signedTransactionInfo);
}

// Client sends the StoreKit2 transaction id + product id after a purchase
// completes; this looks the transaction up directly with Apple's App Store
// Server API (never trusting the client's own claim of success) before
// crediting diamonds, and records the Apple transaction_id so a
// retried/duplicate call can never double-credit.
serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return createResponse({ error: 'Sadece POST istekleri desteklenir.' }, 405);
  }

  if (!APPLE_KEY_ID || !APPLE_ISSUER_ID || !APPLE_PRIVATE_KEY_PEM) {
    return createResponse({ error: 'IAP doğrulama henüz yapılandırılmadı (APPLE_IAP_KEY_ID/APPLE_IAP_ISSUER_ID/APPLE_IAP_PRIVATE_KEY eksik).' }, 500);
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

    const { productId, transactionId } = await req.json();
    if (!productId || !transactionId) {
      return createResponse({ error: 'Eksik parametre: productId, transactionId gerekli.' }, 400);
    }

    const { data: existing } = await supabase
      .from('iap_transactions')
      .select('id, diamonds_credited')
      .eq('transaction_id', transactionId)
      .maybeSingle();

    if (existing) {
      return createResponse({ success: true, alreadyProcessed: true, diamondsCredited: existing.diamonds_credited });
    }

    const appleJwt = await buildAppleJwt();
    const transactionInfo = await fetchTransactionInfo(transactionId, appleJwt);

    if (transactionInfo.transactionId !== transactionId || transactionInfo.productId !== productId) {
      return createResponse({ error: 'İşlem Apple kaydıyla eşleşmedi.' }, 400);
    }
    if (transactionInfo.bundleId !== APPLE_BUNDLE_ID) {
      return createResponse({ error: 'İşlem bu uygulamaya ait değil.' }, 400);
    }
    if (typeof transactionInfo.revocationDate === 'number') {
      return createResponse({ error: 'Bu işlem iade edilmiş.' }, 400);
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

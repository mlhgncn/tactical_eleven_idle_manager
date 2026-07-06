GitHub Secrets required for CI (iOS build & Supabase deploy)

Ready-to-fill values for this repo

iOS Build (Fastlane / App Store Connect)
- APP_STORE_CONNECT_KEY_ID: your App Store Connect API key ID
- APP_STORE_CONNECT_ISSUER_ID: your App Store Connect issuer ID
- APP_STORE_CONNECT_PRIVATE_KEY_BASE64: base64 of your App Store Connect .p8 private key
- APPLE_ID: your Apple developer account email
- TEAM_ID: your Apple Developer Team ID
- BUNDLE_ID: com.melih.tacticaleleven
- FLUTTER_BUILD_NAME: optional, overrides CFBundleShortVersionString (defaults to the version in pubspec.yaml)
- MATCH_GIT_URL / MATCH_PASSWORD: optional — only needed if you later switch to a separate `fastlane match` cert repo. Without them (the default in this repo), `fastlane/Fastfile` creates the Distribution cert + App Store provisioning profile itself via `cert`/`sigh`, using only the App Store Connect API key above, and caches them in `ios_signing_cache/` across CI runs via `actions/cache` (key `ios-signing-v1`) so it only ever mints one certificate. Requires the App Store Connect API key to have the **Admin** role (Developer/App Manager roles can't create certificates). See [README_IOS.md](README_IOS.md) for details.

Supabase deploy
- SUPABASE_DB_URL: your Supabase Postgres connection string (used to apply schema/migrations/seed via psql)
- SUPABASE_URL: your Supabase project URL (e.g. https://xyz.supabase.co)
- SUPABASE_ANON_KEY: your Supabase anon/public API key
 - SUPABASE_SERVICE_ROLE_KEY: (ONLY for server/Edge Function CI) service_role key — do NOT expose to mobile clients
- SUPABASE_ACCESS_TOKEN: personal access token (Supabase dashboard → Account → Access Tokens) used by the Supabase CLI to deploy Edge Functions
- SUPABASE_PROJECT_REF: your project ref (the subdomain in your project URL, e.g. `xyzcompany` from `https://xyzcompany.supabase.co`)

Other useful secrets
- SENTRY_DSN: optional
- FIREBASE_SERVICE_ACCOUNT: optional, if you enable Firebase admin deployment
 - FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64: base64 of ios/Runner/GoogleService-Info.plist (used in iOS CI)
 - REVENUECAT_API_KEY: RevenueCat API key for client SDK (store in CI) — not wired into any screen yet, safe to leave unset
 - ADMOB_INTERSTITIAL_ID: AdMob interstitial ad unit id override (matches `lib/config.dart`'s `ADMOB_INTERSTITIAL_ID`) — AdMob isn't wired into any screen yet either, safe to leave unset

How to add secrets
1. Open your GitHub repository → Settings → Secrets and variables → Actions → New repository secret
2. Add each secret name and value exactly as listed above
3. Keep the values private and do not commit them into the repository

Quick generation examples
- macOS/Linux:
  - base64 -i AuthKey_XXXXXX.p8 | tr -d '\n'
- PowerShell:
  - [Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXX.p8"))

Security notes
- Never commit secrets into repo files.
- Use service_role keys only on server/CI; do not expose them in the mobile client.

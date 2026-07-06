GitHub Secrets required for CI (iOS build & Supabase deploy)

Ready-to-fill values for this repo

iOS Build (Fastlane / App Store Connect)
- APP_STORE_CONNECT_KEY_ID: your App Store Connect API key ID
- APP_STORE_CONNECT_ISSUER_ID: your App Store Connect issuer ID
- APP_STORE_CONNECT_PRIVATE_KEY_BASE64: base64 of your App Store Connect .p8 private key
- APPLE_ID: your Apple developer account email
- TEAM_ID: your Apple Developer Team ID
- BUNDLE_ID: com.melih.tacticaleleven
- MATCH_GIT_URL: optional, only if you use fastlane match
- MATCH_PASSWORD: optional, only if you use fastlane match

Supabase deploy
- SUPABASE_DB_URL: your Supabase Postgres connection string
- SUPABASE_URL: your Supabase project URL (e.g. https://xyz.supabase.co)
- SUPABASE_ANON_KEY: your Supabase anon/public API key
 - SUPABASE_SERVICE_ROLE_KEY: (ONLY for server/Edge Function CI) service_role key — do NOT expose to mobile clients

Other useful secrets
- SENTRY_DSN: optional
- FIREBASE_SERVICE_ACCOUNT: optional, if you enable Firebase admin deployment
 - FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64: base64 of ios/Runner/GoogleService-Info.plist (used in iOS CI)
 - REVENUECAT_API_KEY: RevenueCat API key for client SDK (store in CI)
 - ADMOB_APP_ID: AdMob app id for release builds
 - ADMOB_INTERSTITIAL_AD_UNIT_ID: AdMob interstitial ad unit id (release)
 - ADMOB_REWARDED_AD_UNIT_ID: AdMob rewarded ad unit id (release)

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

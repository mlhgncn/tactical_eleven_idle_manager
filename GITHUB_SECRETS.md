GitHub Secrets required for CI (iOS build & Supabase deploy)

Ready-to-fill values for this repo

iOS Build (Fastlane / App Store Connect)
- APP_STORE_CONNECT_KEY_ID: your App Store Connect API key ID
- APP_STORE_CONNECT_ISSUER_ID: your App Store Connect issuer ID
- APP_STORE_CONNECT_PRIVATE_KEY_BASE64: base64 of your App Store Connect .p8 private key
- APPLE_ID: your Apple developer account email
- TEAM_ID: your Apple Developer Team ID
- BUNDLE_ID: com.melih.tacticaleleven
- MATCH_GIT_URL: required to build — a separate private git repo where `fastlane match` stores your appstore cert/profile (see notes below)
- MATCH_PASSWORD: required alongside MATCH_GIT_URL — passphrase used to encrypt the match repo
- MATCH_KEYCHAIN_PASSWORD: optional, password for the CI keychain match creates (any value; only needs to be consistent within a run)
- MATCH_GIT_BASIC_AUTHORIZATION: base64 `user:PAT` — required if MATCH_GIT_URL is an HTTPS repo the default GITHUB_TOKEN can't reach (i.e. any repo other than this one); generate a fine-grained PAT scoped to just that signing repo with Contents: Read and write
- FLUTTER_BUILD_NAME: optional, overrides CFBundleShortVersionString (defaults to the version in pubspec.yaml)

Note on MATCH_GIT_URL: the regular build workflow (`ios_release.yml`) always runs `match` with `readonly: true`, so it only *fetches* an existing cert/profile — it never creates or revokes one. No Mac required to seed it: run the separate `.github/workflows/ios_match_setup.yml` workflow once (GitHub → Actions → "iOS Signing Setup (one-time)" → Run workflow, type `YES` to confirm) — it creates the Distribution cert + App Store profile on GitHub's macOS runner and pushes them into that repo. Requires the App Store Connect API key to have the **Admin** role (Developer/App Manager roles can't create certificates).

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

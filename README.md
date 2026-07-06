# tactical_eleven_idle_manager

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## TestFlight (iOS) CI release

Steps to prepare and upload a TestFlight build via CI:

- Add repository secrets (Settings → Secrets → Actions):
	- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APPLE_ID`, `TEAM_ID`, `BUNDLE_ID`
	- `SUPABASE_URL`, `SUPABASE_ANON_KEY`
	- `FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64` (base64 of GoogleService-Info.plist)
	- `REVENUECAT_API_KEY`, `ADMOB_APP_ID`, `ADMOB_INTERSTITIAL_AD_UNIT_ID`, `ADMOB_REWARDED_AD_UNIT_ID`
	- (optional) `MATCH_GIT_URL` and `MATCH_PASSWORD` for code signing via fastlane match

- Trigger the iOS workflow: Actions → iOS Build & TestFlight → Run workflow

Local Fastlane command (developer machine):
```bash
export APP_STORE_CONNECT_PRIVATE_KEY_BASE64=$(base64 -w0 AuthKey_XXXXXX.p8)
export SUPABASE_URL="https://xyz.supabase.co"
export SUPABASE_ANON_KEY="your_anon_key"
# optionally set REVENUECAT_API_KEY and ADMOB_*
bundle exec fastlane ios beta
```

Notes:
- CI will decode `FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64` into `ios/Runner/GoogleService-Info.plist` for the build.
- Keep `SUPABASE_SERVICE_ROLE_KEY` only in server/edge CI and never in mobile app secrets.
- Ensure `key.properties` is provided on CI for Android signing (not required for TestFlight).

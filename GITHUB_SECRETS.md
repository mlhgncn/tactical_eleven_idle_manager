GitHub Secrets required for CI (iOS build & Supabase deploy)

iOS Build (Fastlane / App Store Connect)
- APP_STORE_CONNECT_KEY_ID: App Store Connect API Key ID (key identifier)
- APP_STORE_CONNECT_ISSUER_ID: App Store Connect Issuer ID
- APP_STORE_CONNECT_PRIVATE_KEY_BASE64: Base64 encoded .p8 private key content
- APPLE_ID: Apple developer account email
- TEAM_ID: Apple team id
- BUNDLE_ID: App bundle identifier (e.g. com.yourcompany.tacticaleleven)
- MATCH_GIT_URL: (optional) Git URL for fastlane match certificates
- MATCH_PASSWORD: (optional) password for match repo

Supabase deploy
- SUPABASE_DB_URL: Postgres connection string for the project (e.g. "postgres://postgres:password@db.host:5432/postgres")

Other useful secrets
- SENTRY_DSN
- FIREBASE_SERVICE_ACCOUNT (if using Firebase)

How to add secrets
1. Go to your GitHub repository → Settings → Secrets → Actions → New repository secret
2. Add the name and value from above

Security notes
- Never commit secrets into repo files.
- Use `service_role` keys only on server/CI; do not expose in mobile client.

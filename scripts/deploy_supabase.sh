#!/usr/bin/env bash
# Deploy supabase/schema.sql to the database pointed by SUPABASE_DB_URL
set -euo pipefail

if [ -z "${SUPABASE_DB_URL:-}" ]; then
  echo "Please set SUPABASE_DB_URL environment variable (Postgres connection string)"
  exit 1
fi

psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/schema.sql

echo "Supabase schema applied successfully."

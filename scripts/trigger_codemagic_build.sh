#!/usr/bin/env bash
# Trigger Codemagic build for workflow 'ios-release'
# Requires: CODEMAGIC_API_TOKEN, APP_ID (Codemagic app id), WORKFLOW_ID
# Usage: CODEMAGIC_API_TOKEN=xxx APP_ID=your-app-id WORKFLOW_ID=ios-release ./scripts/trigger_codemagic_build.sh

if [ -z "$CODEMAGIC_API_TOKEN" ] || [ -z "$APP_ID" ] || [ -z "$WORKFLOW_ID" ]; then
  echo "Missing required env vars: CODEMAGIC_API_TOKEN, APP_ID, WORKFLOW_ID"
  exit 1
fi

curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "x-auth-token: $CODEMAGIC_API_TOKEN" \
  -d '{"workflow_id":"'$WORKFLOW_ID'","branch":"main","environment":{}}' \
  "https://api.codemagic.io/apps/$APP_ID/builds" \
  | jq '.'

#!/usr/bin/env bash
# Trigger GitHub Actions workflow dispatch for iOS release
# Uses the repository: mlhgncn/tactical_eleven_idle_manager by default
# Requires: GITHUB_TOKEN (Personal Access Token with `repo` and `workflow` scopes) or GH_TOKEN
# Optional environment variables:
# - WORKFLOW_FILE (default: ios_release.yml)
# - REF (default: main)
# Usage:
# GITHUB_TOKEN=ghp_xxx ./scripts/trigger_codemagic_build.sh

set -euo pipefail

GITHUB_TOKEN=${GITHUB_TOKEN:-${GH_TOKEN:-}}
WORKFLOW_FILE=${WORKFLOW_FILE:-ios_release.yml}
REF=${REF:-main}
OWNER=${OWNER:-mlhgncn}
REPO=${REPO:-tactical_eleven_idle_manager}

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Missing GITHUB_TOKEN or GH_TOKEN. Create a PAT with 'repo' and 'workflow' scopes."
  exit 1
fi

API_URL="https://api.github.com/repos/${OWNER}/${REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches"

echo "Triggering workflow ${WORKFLOW_FILE} on ${OWNER}/${REPO} (ref=${REF})"

curl -s -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"ref\": \"${REF}\"}" \
  "$API_URL" | jq '.' || true

echo "Dispatched. Check Actions tab for progress."

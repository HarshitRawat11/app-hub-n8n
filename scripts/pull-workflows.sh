#!/usr/bin/env bash
#
# Pull every workflow from the n8n instance into workflows/, one JSON file each.
#
# Run from WSL (jq lives there, not on Windows):
#   wsl -e bash -lc "cd /mnt/c/Users/harshit.rawat/Documents/Projects/app-hub/n8n && ./scripts/pull-workflows.sh"
#
# Reads N8N_BASE_URL and N8N_API_KEY from .env. The key is never printed.

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "error: .env not found. Copy .env.example to .env and fill it in." >&2
  exit 1
fi

# set -a exports everything defined until set +a, so the vars reach the subshells below.
set -a
# shellcheck disable=SC1091
. ./.env
set +a

: "${N8N_BASE_URL:?not set in .env}"
: "${N8N_API_KEY:?not set in .env}"

command -v jq >/dev/null || { echo "error: jq not installed (apt install jq)" >&2; exit 1; }

mkdir -p workflows

echo "Fetching workflows from ${N8N_BASE_URL} ..."

# --fail turns HTTP errors into a non-zero exit instead of a body we'd try to parse.
# Never add -v here: verbose mode prints request headers, API key included.
response=$(curl -sS --fail \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  "${N8N_BASE_URL}/api/v1/workflows?limit=250")

count=$(jq '.data | length' <<<"$response")
echo "Found ${count} workflow(s)."

# Write one file per workflow, named by a slug of its name plus its id, so a rename
# doesn't silently orphan the old file and the id keeps names unique.
jq -c '.data[]' <<<"$response" | while read -r wf; do
  id=$(jq -r '.id' <<<"$wf")
  name=$(jq -r '.name' <<<"$wf")
  slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')
  file="workflows/${slug}-${id}.json"

  # Strip volatile server-side fields so a re-pull with no real change is an empty diff.
  jq 'del(.createdAt, .updatedAt, .versionId)' <<<"$wf" > "$file"
  echo "  wrote ${file}"
done

echo
echo "Done. Review before committing — check for secrets typed directly into nodes:"
echo "  grep -riE '(api[-_]?key|token|secret|password|bearer)' workflows/ | grep -vi '\"name\"'"

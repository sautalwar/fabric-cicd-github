#!/bin/bash
# import-pbix.sh — Upload a .pbix file to a Power BI workspace via REST API
#
# Usage: import-pbix.sh <pbix-file-path> <workspace-id> <access-token>
#
# Environment variables (alternative to positional args):
#   PBIX_FILE_PATH, POWERBI_WORKSPACE_ID, ACCESS_TOKEN
#
# Exit codes:
#   0 = success
#   1 = failure (API error or import failed)
#   2 = timeout (import did not complete within 10 minutes)

set -euo pipefail

# --- Configuration ---
POLL_INTERVAL=10       # seconds between status checks
MAX_POLLS=60           # 60 * 10s = 10 minutes
API_BASE="https://api.powerbi.com/v1.0/myorg"

# --- Parse arguments ---
PBIX_PATH="${1:-${PBIX_FILE_PATH:-}}"
WORKSPACE_ID="${2:-${POWERBI_WORKSPACE_ID:-}}"
TOKEN="${3:-${ACCESS_TOKEN:-}}"

if [[ -z "$PBIX_PATH" || -z "$WORKSPACE_ID" || -z "$TOKEN" ]]; then
  echo "❌ Usage: import-pbix.sh <pbix-file-path> <workspace-id> <access-token>"
  echo "   Or set PBIX_FILE_PATH, POWERBI_WORKSPACE_ID, ACCESS_TOKEN environment variables."
  exit 1
fi

if [[ ! -f "$PBIX_PATH" ]]; then
  echo "❌ File not found: $PBIX_PATH"
  exit 1
fi

# --- Extract and URL-encode the display name ---
FILENAME=$(basename "$PBIX_PATH" .pbix)
ENCODED_NAME=$(printf '%s' "$FILENAME" | jq -sRr @uri)

echo "📦 Importing: $FILENAME"
echo "   Workspace: $WORKSPACE_ID"
echo "   File: $PBIX_PATH"
echo ""

# --- Upload PBIX via POST /imports ---
IMPORT_URL="${API_BASE}/groups/${WORKSPACE_ID}/imports?datasetDisplayName=${ENCODED_NAME}&nameConflict=CreateOrOverwrite"

echo "⬆️  Uploading to Power BI..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "$IMPORT_URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@${PBIX_PATH}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
  echo "❌ Upload failed with HTTP $HTTP_CODE"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  exit 1
fi

IMPORT_ID=$(echo "$BODY" | jq -r '.id')
if [[ -z "$IMPORT_ID" || "$IMPORT_ID" == "null" ]]; then
  echo "❌ Failed to extract import ID from response"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  exit 1
fi

echo "✅ Upload accepted. Import ID: $IMPORT_ID"
echo ""

# --- Poll import status ---
echo "⏳ Polling import status (every ${POLL_INTERVAL}s, timeout ${MAX_POLLS} polls)..."
STATUS_URL="${API_BASE}/groups/${WORKSPACE_ID}/imports/${IMPORT_ID}"

for ((i=1; i<=MAX_POLLS; i++)); do
  sleep "$POLL_INTERVAL"

  STATUS_RESPONSE=$(curl -s \
    -H "Authorization: Bearer $TOKEN" \
    "$STATUS_URL")

  IMPORT_STATE=$(echo "$STATUS_RESPONSE" | jq -r '.importState')

  case "$IMPORT_STATE" in
    "Succeeded")
      DATASET_ID=$(echo "$STATUS_RESPONSE" | jq -r '.datasets[0].id // empty')
      REPORT_ID=$(echo "$STATUS_RESPONSE" | jq -r '.reports[0].id // empty')

      echo ""
      echo "🎉 Import succeeded!"
      echo "   Dataset ID: ${DATASET_ID:-N/A}"
      echo "   Report ID:  ${REPORT_ID:-N/A}"
      echo ""

      # Output for GitHub Actions
      if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "dataset_id=${DATASET_ID}" >> "$GITHUB_OUTPUT"
        echo "report_id=${REPORT_ID}" >> "$GITHUB_OUTPUT"
        echo "import_status=succeeded" >> "$GITHUB_OUTPUT"
      fi

      exit 0
      ;;
    "Failed")
      echo ""
      echo "❌ Import failed!"
      echo "$STATUS_RESPONSE" | jq '.errors // .error // .' 2>/dev/null
      exit 1
      ;;
    *)
      printf "   Poll %d/%d — Status: %s\r" "$i" "$MAX_POLLS" "$IMPORT_STATE"
      ;;
  esac
done

echo ""
echo "⏰ Timeout: Import did not complete within $((MAX_POLLS * POLL_INTERVAL)) seconds"
echo "   Last status: $IMPORT_STATE"
echo "   Import ID: $IMPORT_ID (check Power BI portal for status)"
exit 2

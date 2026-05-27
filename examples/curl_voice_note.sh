#!/usr/bin/env bash
# Submit a short voice note as a multipart upload, poll until terminal, print the transcript.
# Requires: scribed running at localhost:3000 (docker compose up).
set -euo pipefail

SCRIBED_URL="${SCRIBED_URL:-http://localhost:3000}"
SCRIBED_API_KEY="${SCRIBED_API_KEY:-change-me-dev-key}"
SAMPLE="$(dirname "$0")/samples/voice_note.wav"

echo "-> Submitting $SAMPLE to $SCRIBED_URL/v1/transcriptions ..."
RESPONSE=$(curl -sf -X POST "$SCRIBED_URL/v1/transcriptions" \
  -H "Authorization: Bearer $SCRIBED_API_KEY" \
  -F "audio=@$SAMPLE" \
  -F "language=en")

ID=$(echo "$RESPONSE" | jq -r .id)
echo "  job id: $ID"

echo "-> Polling for completion ..."
for i in $(seq 1 60); do
  STATE=$(curl -sf -H "Authorization: Bearer $SCRIBED_API_KEY" \
    "$SCRIBED_URL/v1/transcriptions/$ID")
  STATUS=$(echo "$STATE" | jq -r .status)
  echo "  attempt $i: status=$STATUS"
  case "$STATUS" in
    completed|failed|cancelled) break ;;
  esac
  sleep 2
done

echo "-> Final result:"
echo "$STATE" | jq '{id, status, text, language, duration_seconds, segments: (.segments | length)}'

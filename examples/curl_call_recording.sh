#!/usr/bin/env bash
# Submit a longer recording to Deepgram with native diarization.
#
# Why Deepgram for diarization?
# Deepgram returns speaker labels in a single round-trip. The pyannote path also
# works (provider=openai_compatible diarize=true) but it needs a public callback
# URL set via PYANNOTE_WEBHOOK_BASE_URL (use ngrok for local).
#
# Requires: scribed running at localhost:3000, DEEPGRAM_API_KEY in scribed's env.
set -euo pipefail

SCRIBED_URL="${SCRIBED_URL:-http://localhost:3000}"
SCRIBED_API_KEY="${SCRIBED_API_KEY:-change-me-dev-key}"
SAMPLE="$(dirname "$0")/samples/call_recording.wav"

if [ -z "${DEEPGRAM_API_KEY:-}" ]; then
  if ! docker compose exec -T web printenv DEEPGRAM_API_KEY >/dev/null 2>&1; then
    echo "DEEPGRAM_API_KEY not set in your shell or scribed's env."
    echo "Set it in .env and restart docker compose, or export it and re-run."
    exit 0
  fi
fi

echo "-> Submitting $SAMPLE (provider=deepgram, diarize=true) ..."
RESPONSE=$(curl -sf -X POST "$SCRIBED_URL/v1/transcriptions" \
  -H "Authorization: Bearer $SCRIBED_API_KEY" \
  -F "audio=@$SAMPLE" \
  -F "provider=deepgram" \
  -F "diarize=true" \
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
echo "$STATE" | jq '{id, status, text, language, duration_seconds, speakers: [.segments[]?.speaker] | unique, segment_count: (.segments | length)}'

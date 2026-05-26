# scribed

Self-hostable, provider-agnostic audio transcription microservice.

## Why

Chatwoot shipped built-in voice-message transcription via OpenAI in mid-2025. That works great if you're happy sending audio to OpenAI. scribed exists for teams who want the same capability on infrastructure they control, with the freedom to pick a backend: whisper.cpp, faster-whisper, Deepgram, OpenAI, or anything else that lands. One REST API, swappable providers, no lock-in.

## Quickstart

```bash
cp .env.example .env
docker compose up
```

Submit a job (placeholder — full API lands in v0.1):

```bash
curl -X POST http://localhost:3000/v1/transcriptions \
  -H "Authorization: Bearer change-me-dev-key" \
  -F "audio=@sample.wav"
```

## Architecture

REST API (Rails 8 API-only) writes jobs to Postgres and enqueues to Sidekiq. Workers stream audio to a pluggable provider sidecar (default: a local whisper.cpp container exposing the OpenAI-compatible `/v1/audio/transcriptions` endpoint). Results are persisted and optionally POSTed to a webhook signed with an HMAC secret.

```
client → Rails API → Postgres
                  ↓
              Sidekiq → Provider (whisper / Deepgram / OpenAI / …)
                     → Webhook
```

## Roadmap

- **v0.1** — synchronous + async transcription, OpenAI-compatible provider, API-key auth, webhooks.
- **v0.2** — diarization (pyannote), word-level timestamps, multiple language hints, retries with backoff.
- **v0.3** — multi-tenant projects, per-project provider routing, usage metering, admin UI.

## License

MIT — see [LICENSE](LICENSE).

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

Workers process two queues: `transcriptions` (compute-bound, concurrency 2) and `webhooks` (network-bound, concurrency 1). The default queue handles ad-hoc jobs.

## Providers

scribed ships with four providers out of the box. Configure the default in `config/transcription.yml` or via the `DEFAULT_PROVIDER` env var.

| Provider | Backend | Diarization | Streaming | Notes |
|---|---|---|---|---|
| `openai_compatible` | Any OpenAI-API-shaped endpoint (faster-whisper-server, hwdsl2/docker-whisper, Groq, Together, …) | No | No | **Default.** Bundled `whisper` service runs `faster-whisper-server` on CPU. |
| `openai` | api.openai.com | No | No | Set `OPENAI_API_KEY`. 25 MB file limit. |
| `whisper_cpp` | In-process via `whispercpp` gem | No | No | Slowest. No external deps once model is downloaded. Good fallback. |
| `deepgram` | api.deepgram.com | Yes (native) | Yes (Phase 6) | Set `DEEPGRAM_API_KEY`. |

Adding a provider: subclass `Providers::Base`, implement `#transcribe(audio_path, **opts)` returning a `Providers::Result`, register it in `config/transcription.yml`.

## API

All requests require `Authorization: Bearer <SCRIBED_API_KEY>`. Errors come back as `{"error":{"code","message"}}`.

### Submit a transcription

```bash
curl -i -X POST http://localhost:3000/v1/transcriptions \
  -H "Authorization: Bearer change-me-dev-key" \
  -F "audio=@sample.wav" \
  -F "provider=openai_compatible" \
  -F "language=en"
# 202 Accepted
# Location: /v1/transcriptions/<uuid>
# { "id": "...", "status": "pending", "created_at": "..." }
```

Or by URL:

```bash
curl -i -X POST http://localhost:3000/v1/transcriptions \
  -H "Authorization: Bearer change-me-dev-key" \
  -H "Content-Type: application/json" \
  -d '{"audio_url":"https://example.com/sample.mp3","callback_url":"https://you/hook"}'
```

### Fetch a transcription

```bash
curl -H "Authorization: Bearer change-me-dev-key" \
  http://localhost:3000/v1/transcriptions/<uuid>
```

### Delete

```bash
curl -X DELETE -H "Authorization: Bearer change-me-dev-key" \
  http://localhost:3000/v1/transcriptions/<uuid>
# 204 No Content
```

## Webhooks

When you POST a transcription with `callback_url`, scribed will POST the full serialized transcription to that URL when it reaches a terminal state (`completed`, `failed`, or `cancelled`).

Each request includes:
- `X-Scribed-Event` — `transcription.completed` | `transcription.failed` | `transcription.cancelled`
- `X-Scribed-Signature` — `sha256=<hex>` HMAC of the body, computed with the per-record secret (or `SCRIBED_WEBHOOK_SECRET` fallback)
- `User-Agent: scribed/0.1`

Verify the signature server-side before trusting the payload:

```ruby
expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, request.body.read)
ActiveSupport::SecurityUtils.secure_compare(expected, request.headers["X-Scribed-Signature"])
```

Delivery uses Sidekiq with exponential backoff retries (up to ~5 attempts in v0.1, ~25 in production tuning).

## Diarization

For providers that don't support speaker labels natively (everything except Deepgram), pass `diarize: true` and provide an `audio_url`. scribed submits the audio to [pyannote.ai](https://pyannote.ai) asynchronously and waits for a callback. When the callback lands, scribed merges speaker labels into the existing transcription segments and fires the user webhook.

```bash
curl -X POST http://localhost:3000/v1/transcriptions \
  -H "Authorization: Bearer change-me-dev-key" \
  -H "Content-Type: application/json" \
  -d '{
    "audio_url": "https://example.com/call.mp3",
    "provider": "openai_compatible",
    "diarize": true,
    "callback_url": "https://you/hook"
  }'
```

Requirements:
- `PYANNOTE_API_KEY` set
- `PYANNOTE_WEBHOOK_BASE_URL` set to the public URL of your scribed deployment (so pyannote can call back). Use ngrok for local testing.
- `audio_url` is required (pyannote can't fetch ActiveStorage blobs without exposing signed URLs — coming in a future phase).

Native Deepgram diarization (no pyannote round-trip) works synchronously: just pass `provider: "deepgram"` and `diarize: true`.

## Roadmap

- **v0.1** — synchronous + async transcription, OpenAI-compatible provider, API-key auth, webhooks.
- **v0.2** — diarization (pyannote), word-level timestamps, multiple language hints, retries with backoff.
- **v0.3** — multi-tenant projects, per-project provider routing, usage metering, admin UI.

## License

MIT — see [LICENSE](LICENSE).

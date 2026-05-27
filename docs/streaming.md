# Streaming architecture (planned for v0.3)

Real-time, low-latency transcription via WebSocket. Stubbed today; this doc lets v0.3 implementers execute without re-deriving the design.

## Why streaming

Use cases: live call agent-assist (e.g. Chatwoot voice channel), in-meeting captions, push-to-talk dictation with sub-second feedback. Streaming here means partial transcripts emitted as the client uploads audio chunks, not batch transcription of completed audio.

## Provider landscape

| Provider | Streaming endpoint | Status | Notes |
|---|---|---|---|
| `deepgram` | `wss://api.deepgram.com/v1/listen` | v0.3 primary target | Native WS, low latency, supports diarization in stream. |
| `openai` | `wss://api.openai.com/v1/realtime?model=gpt-4o-transcribe` | Deferred follow-up | Realtime API, newer surface, fewer reference impls. |
| `openai_compatible` | depends on sidecar | Deferred | `faster-whisper-server` does NOT stream. Would need a separate `whisper_streaming_web` sidecar. |
| `whisper_cpp` | local streaming binary | Deferred | CPU latency too high to be useful. |

## Transport: ActionCable

Rails-native, Redis-backed (already in the stack), no new infrastructure.

Candidate WebSocket client libs (server → provider direction):
- **`faye-websocket`** — battle-tested, EventMachine-based, plays with Puma. **Recommended for v0.3.**
- `async-websocket` — better fit if we ever move to Falcon.
- `websocket-client-simple` — lightest, fewest features.

## Message protocol

Client → server (via ActionCable `data` payload):

```json
{ "event": "start", "config": { "provider": "deepgram", "language": "en", "diarize": true } }
{ "event": "audio", "chunk": "<base64-encoded PCM/Opus/WAV chunk>" }
{ "event": "end" }
```

Server → client (via `transmit`):

```json
{ "event": "partial", "text": "...", "segments": [...] }
{ "event": "final",   "text": "...", "segments": [...] }
{ "event": "error",   "code": "...", "message": "..." }
{ "event": "completed", "transcription": { /* full serialized */ } }
```

## State model

Phase 6 adds `"streaming"` to `Transcription::STATUSES`. Transition methods land in v0.3.

```
pending → streaming → completed
                  ↘ failed
                  ↘ cancelled  (client disconnect, no flush)
```

## Required model method (v0.3, do not implement now)

```ruby
def append_segments!(new_segments)
  self.segments = (segments || []) + Array(new_segments)
  save!
  self
end
```

Also add `mark_streaming!` and a `streaming` scope.

## Auth at the WebSocket layer

`ApplicationCable::Connection` reads the bearer token from `Authorization: Bearer ...` or `?token=...` query param. Mirrors the REST auth in `app/controllers/concerns/api_authenticatable.rb`. Both use `ActiveSupport::SecurityUtils.secure_compare` and both fall open when `Scribed.config.api_key.blank?` for dev convenience.

## Error handling

- **Provider WebSocket drop:** exponential backoff `[0.5, 1, 2, 4, 8]s`, max 5 attempts. Then emit `{event: "error", code: "provider_unreachable"}` and disconnect the client.
- **Client disconnect without `{event: "end"}`:** call `mark_cancelled!` and flush any pending segments via `append_segments!`.

## Implementation steps for v0.3

1. ~~Add `streaming` to `STATUSES`~~ (done in Phase 6)
2. Add `append_segments!` and `mark_streaming!` to `Transcription`
3. Add a `Providers::Streaming` mixin exposing `open_stream(audio_io, callbacks)`
4. Implement a Deepgram WebSocket client (use `faye-websocket`)
5. Flesh out `TranscriptionChannel` with `subscribed` / `receive` / `unsubscribed`
6. Add channel spec + request spec covering the WS handshake
7. Update README with a Live Streaming section + a JS subscription snippet

## Not in scope for v0.3

- Multi-language interim captions
- Per-account custom vocabularies
- Per-segment confidence threshold filtering

## Open questions

- **WebSocket client lib choice** — faye-websocket vs async-websocket vs websocket-client-simple. Default recommendation above; revisit if the threading model bites us.
- **Bridging ActionCable's threaded model with the provider's persistent WebSocket connection** — fiber per channel? Thread? Background job? Has perf + lifecycle implications.
- **Multiplexed providers** — should one channel be able to fan out to Deepgram (transcription) + pyannote (live diarization) simultaneously? If so, the message protocol needs a `source` field on each `partial`/`final`.

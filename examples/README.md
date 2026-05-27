# scribed examples

Runnable demos that exercise the v0.1 API surface end-to-end.

## Quickstart

```bash
docker compose up -d
chmod +x examples/curl_voice_note.sh
examples/curl_voice_note.sh
```

The first `docker compose up` pulls the `faster-whisper-server` image and
downloads the whisper model on first transcription (~2 min). Subsequent
runs are fast.

## What's here

| Path | What it shows |
|---|---|
| [`curl_voice_note.sh`](curl_voice_note.sh) | Multipart upload -> poll -> transcript. Fastest sanity check. |
| [`curl_call_recording.sh`](curl_call_recording.sh) | Deepgram provider with native speaker diarization. |
| [`chatwoot_webhook_bridge/`](chatwoot_webhook_bridge/) | Sinatra app wiring scribed into Chatwoot's `message_created` webhook. |
| [`samples/CREDITS.md`](samples/CREDITS.md) | Sample audio attribution and re-download instructions. |

## Provider matrix at a glance

- `openai_compatible` (default) -- works with the bundled `whisper` sidecar, zero
  external credentials needed.
- `deepgram` -- set `DEEPGRAM_API_KEY` in `.env`. Native diarization, fast.
- `openai` -- set `OPENAI_API_KEY` in `.env`. 25 MB file cap.
- `whisper_cpp` -- fully local, slowest, no network egress.

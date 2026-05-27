# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
-

### Changed
-

### Fixed
-

## [0.1.0] - 2026-05-27

### Added
- REST API v1: `POST/GET/DELETE /v1/transcriptions` with bearer-token auth
- Multipart upload and `audio_url` JSON submission paths
- Pluggable provider layer: `openai`, `openai_compatible` (default), `whisper_cpp`, `deepgram`
- Bundled `faster-whisper-server` sidecar in docker-compose for zero-credential default
- Async transcription via Sidekiq with `transcriptions` and `webhooks` queues
- Signed outbound webhooks (`X-Scribed-Signature: sha256=<hex>`, per-record secret with `SCRIBED_WEBHOOK_SECRET` fallback) and `X-Scribed-Event` header
- Pyannote diarization sidecar with callback receiver at `/v1/transcriptions/:id/webhook`
- Deepgram native diarization (no pyannote round-trip)
- ActionCable `TranscriptionChannel` stub reserving the v0.3 streaming route
- Demo curl scripts and Chatwoot webhook bridge example under `examples/`
- 78 RSpec examples covering models, services, controllers, jobs, and providers

### Changed
- N/A (first tagged release)

### Fixed
- N/A (first tagged release)

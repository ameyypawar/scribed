# Audio fixtures

- `sample.wav` — 3-second CC0 sample from https://samplelib.com/lib/preview/wav/sample-3s.wav.
  Used by `WhisperCpp` native specs (gated by `RUN_NATIVE_SPECS=true`).
  Download:
    curl -L -o spec/fixtures/audio/sample.wav https://samplelib.com/lib/preview/wav/sample-3s.wav

- `silence.wav` — generated stub (RIFF header only) used by WebMock-stubbed specs.
  Auto-created by spec setup; do not edit.

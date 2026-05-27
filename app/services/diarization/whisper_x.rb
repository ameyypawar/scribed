module Diarization
  class WhisperX < Base
    def submit(_transcription)
      raise DiarizerError.new("whisper_x: not implemented yet (Phase 5+ work)")
    end
  end
end

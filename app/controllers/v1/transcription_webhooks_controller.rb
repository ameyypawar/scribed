module V1
  class TranscriptionWebhooksController < BaseController
    # TODO(Phase 5): verify provider HMAC, hydrate segments/diarization from
    # pyannote callback payload, transition status.
    def receive
      Transcription.find(params[:id])
      head :no_content
    end
  end
end

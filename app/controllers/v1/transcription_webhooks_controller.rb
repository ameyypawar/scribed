module V1
  class TranscriptionWebhooksController < BaseController
    # pyannote.ai does NOT sign webhook callbacks. Authentication is via:
    #   1) Hard-to-guess UUID :id in the path
    #   2) body["jobId"] must match record.external_job_id
    # A confused-deputy attacker would also need to know that job id.
    skip_before_action :authenticate!

    def receive
      record = Transcription.find(params[:id])
      payload = parse_body

      unless payload["jobId"].to_s == record.external_job_id.to_s && record.external_job_id.present?
        render json: { error: { code: "jobId_mismatch", message: "jobId does not match" } },
               status: :unprocessable_entity
        return
      end

      case payload["status"]
      when "succeeded"
        handle_success(record, payload)
      when "failed"
        record.mark_failed!(payload["error"].presence || "pyannote diarization failed")
      else
        render json: { error: { code: "unknown_status", message: "unknown status" } },
               status: :unprocessable_entity
        return
      end

      WebhookJob.perform_later(record.id) if record.webhook_url.present?
      head :no_content
    end

    private

    def parse_body
      raw = request.raw_post
      raw.present? ? JSON.parse(raw) : {}
    rescue JSON::ParserError
      {}
    end

    def handle_success(record, payload)
      diarization = Array(payload.dig("output", "diarization"))
      merged = SegmentMerger.merge(Array(record.segments), diarization)
      record.mark_completed!(
        transcript: record.transcript,
        metadata: record.provider_metadata,
        segments: merged,
        diarization: diarization,
        language: record.language,
        duration: record.audio_duration_seconds
      )
    end
  end
end

require "faraday"
require "json"

module Diarization
  class Pyannote < Base
    DEFAULT_ENDPOINT = "https://api.pyannote.ai/v1/diarize".freeze

    def async?
      true
    end

    def submit(transcription)
      key = config[:api_key].presence || ENV[config[:api_key_env].to_s]
      raise DiarizerError.new("pyannote: missing API key") if key.blank?
      if transcription.audio_url.blank?
        raise DiarizerError.new("pyannote: requires audio_url (ActiveStorage-only audio not supported in v0.1)")
      end

      base = ENV["PYANNOTE_WEBHOOK_BASE_URL"].presence || "http://localhost:3000"
      callback_url = "#{base.chomp('/')}/v1/transcriptions/#{transcription.id}/webhook"

      endpoint = config[:endpoint] || DEFAULT_ENDPOINT
      body = JSON.generate(
        url: transcription.audio_url,
        webhook: callback_url,
        webhookId: transcription.id
      )

      response = Faraday.post(endpoint) do |req|
        req.headers["Authorization"] = "Bearer #{key}"
        req.headers["Content-Type"] = "application/json"
        req.body = body
      end

      if response.status >= 400
        raise DiarizerError.new("pyannote: HTTP #{response.status}", status: response.status, body: response.body)
      end

      parsed = JSON.parse(response.body)
      job_id = parsed["jobId"] || parsed["job_id"]
      raise DiarizerError.new("pyannote: missing jobId in response") if job_id.blank?
      job_id
    rescue Faraday::Error => e
      raise DiarizerError.new("pyannote: #{e.message}")
    end
  end
end

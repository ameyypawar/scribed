require "faraday"
require "json"

module Providers
  class Deepgram < Base
    DEFAULT_MODEL = "nova-3".freeze
    ENDPOINT = "https://api.deepgram.com/v1/listen".freeze

    def supports_diarization?
      true
    end

    def supports_streaming?
      true
    end

    def transcribe(audio_path, **opts)
      key = resolved_api_key || ENV["DEEPGRAM_API_KEY"]
      raise ProviderError.new("deepgram: missing API key") if key.blank?

      query = {
        model: opts[:model] || config[:model] || DEFAULT_MODEL,
        smart_format: true,
        diarize: opts[:diarize] ? true : false
      }
      query[:language] = opts[:language] if opts[:language]

      conn = Faraday.new(url: ENDPOINT)
      response = conn.post do |req|
        req.params = query
        req.headers["Authorization"] = "Token #{key}"
        req.headers["Content-Type"] = opts[:content_type] || "audio/wav"
        req.body = File.binread(audio_path)
      end

      if response.status >= 400
        raise ProviderError.new("deepgram: HTTP #{response.status}", status: response.status, body: response.body)
      end

      body = JSON.parse(response.body)
      build_result(body)
    rescue Faraday::Error => e
      raise ProviderError.new("deepgram: #{e.message}")
    end

    private

    def build_result(body)
      alt = body.dig("results", "channels", 0, "alternatives", 0) || {}
      text = alt["transcript"].to_s
      words = Array(alt["words"])
      segments = group_words_into_segments(words)
      duration = body.dig("metadata", "duration")
      Result.new(
        text: text,
        language: body.dig("results", "channels", 0, "detected_language"),
        duration: duration,
        segments: segments,
        raw: body
      )
    end

    def group_words_into_segments(words)
      return [] if words.empty?
      groups = []
      current = nil
      words.each do |w|
        speaker = w["speaker"]
        if current.nil? || current[:speaker] != speaker
          groups << current if current
          current = { speaker: speaker, "start" => w["start"], "end" => w["end"], "text" => w["punctuated_word"] || w["word"] }
        else
          current["end"] = w["end"]
          current["text"] = "#{current["text"]} #{w["punctuated_word"] || w["word"]}".strip
        end
      end
      groups << current if current
      groups
    end
  end
end

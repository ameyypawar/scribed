require "openai"

module Providers
  class Openai < Base
    DEFAULT_MODEL = "whisper-1".freeze

    def transcribe(audio_path, **opts)
      key = resolved_api_key || ENV["OPENAI_API_KEY"]
      client = ::OpenAI::Client.new(access_token: key)
      params = {
        model: opts[:model] || config[:model] || DEFAULT_MODEL,
        file: File.open(audio_path, "rb"),
        response_format: "verbose_json",
        temperature: opts[:temperature] || 0.2
      }
      params[:language] = opts[:language] if opts[:language]
      params[:prompt] = opts[:prompt] if opts[:prompt]
      response = client.audio.transcribe(parameters: params)
      build_result(response)
    rescue Faraday::Error => e
      raise ProviderError.new("openai: #{e.message}", status: e.respond_to?(:response_status) ? e.response_status : nil)
    rescue StandardError => e
      raise ProviderError.new("openai: #{e.message}")
    end

    private

    def build_result(response)
      segments = Array(response["segments"]).map do |s|
        { "start" => s["start"], "end" => s["end"], "text" => s["text"] }
      end
      Result.new(
        text: response["text"],
        language: response["language"],
        duration: response["duration"],
        segments: segments,
        raw: response
      )
    end
  end
end

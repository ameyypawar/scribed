require "openai"

module Providers
  class OpenaiCompatible < Openai
    DEFAULT_MODEL = "Systran/faster-whisper-small".freeze
    DEFAULT_BASE_URL = "http://whisper:8000/v1".freeze

    def transcribe(audio_path, **opts)
      key = resolved_api_key || ENV["WHISPER_API_KEY"] || "not-needed"
      base = ENV["WHISPER_BASE_URL"].presence || config[:base_url] || DEFAULT_BASE_URL
      client = ::OpenAI::Client.new(access_token: key, uri_base: base)
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
      raise ProviderError.new("openai_compatible: #{e.message}", status: e.respond_to?(:response_status) ? e.response_status : nil)
    rescue StandardError => e
      raise ProviderError.new("openai_compatible: #{e.message}")
    end
  end
end

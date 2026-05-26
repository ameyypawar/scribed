module Providers
  class WhisperCpp < Base
    DEFAULT_MODEL = "base.en".freeze

    def transcribe(audio_path, **opts)
      require "whisper"
      model = opts[:model] || config[:model] || DEFAULT_MODEL
      context = ::Whisper::Context.new(model)
      params = ::Whisper::Params.new(
        language: opts[:language] || "auto",
        n_processors: config[:n_processors] || 1
      )
      context.transcribe(audio_path, params)

      segments = []
      full_text = +""
      context.each_segment do |seg|
        segments << { "start" => seg.start_time, "end" => seg.end_time, "text" => seg.text }
        full_text << seg.text
      end

      Result.new(
        text: full_text.strip,
        language: opts[:language] || "auto",
        duration: segments.last&.dig("end"),
        segments: segments,
        raw: { "segments" => segments }
      )
    rescue StandardError => e
      raise ProviderError.new("whisper_cpp: #{e.message}")
    end
  end
end

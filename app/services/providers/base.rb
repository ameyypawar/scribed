module Providers
  class Base
    attr_reader :config

    def initialize(config = {})
      @config = config || {}
    end

    def name
      self.class.name.demodulize.underscore
    end

    def transcribe(audio_path, **opts)
      raise NotImplementedError, "#{self.class} must implement #transcribe"
    end

    def supports_streaming?
      false
    end

    def supports_diarization?
      false
    end

    def max_file_bytes
      Scribed.config.max_file_bytes
    end

    private

    def resolved_api_key
      return config[:api_key] if config[:api_key].present?
      env = config[:api_key_env]
      env.present? ? ENV[env] : nil
    end
  end
end

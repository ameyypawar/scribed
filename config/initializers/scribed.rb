require "yaml"

module Scribed
  Config = Struct.new(
    :default_provider,
    :max_file_bytes,
    :providers,
    :api_key,
    :webhook_secret,
    :diarizers,
    :default_diarizer,
    keyword_init: true
  )

  class << self
    attr_accessor :config
  end

  raw = YAML.safe_load_file(Rails.root.join("config/transcription.yml"), permitted_classes: [Symbol]) || {}

  providers = (raw["providers"] || {}).each_with_object({}) do |(name, cfg), acc|
    acc[name.to_sym] = cfg.transform_keys(&:to_sym)
  end

  diarizers = (raw["diarizers"] || {}).each_with_object({}) do |(name, cfg), acc|
    acc[name.to_sym] = cfg.transform_keys(&:to_sym)
  end

  if ENV["WHISPER_BASE_URL"].present? && providers[:openai_compatible]
    providers[:openai_compatible][:base_url] = ENV["WHISPER_BASE_URL"]
  end

  default = ENV["DEFAULT_PROVIDER"].presence || raw["default"] || "openai_compatible"
  default_diarizer = (raw["default_diarizer"] || "pyannote").to_sym

  self.config = Config.new(
    default_provider: default.to_sym,
    max_file_bytes: 25 * 1024 * 1024,
    providers: providers,
    api_key: ENV["SCRIBED_API_KEY"],
    webhook_secret: ENV["SCRIBED_WEBHOOK_SECRET"],
    diarizers: diarizers,
    default_diarizer: default_diarizer
  )
end

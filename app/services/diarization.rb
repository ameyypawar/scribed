module Diarization
  class Error < StandardError; end
  class UnknownDiarizer < Error; end
  class DiarizerError < Error
    attr_reader :status, :body
    def initialize(message, status: nil, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  module_function

  def resolve(name)
    key = name.to_sym
    cfg = Scribed.config.diarizers[key]
    raise UnknownDiarizer, "unknown diarizer: #{name}" unless cfg
    klass = cfg[:class].constantize
    klass.new(cfg)
  end

  def default
    resolve(Scribed.config.default_diarizer)
  end
end

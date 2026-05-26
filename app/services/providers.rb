module Providers
  class Error < StandardError; end
  class UnknownProvider < Error; end
  class ProviderError < Error
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
    cfg = Scribed.config.providers[key]
    raise UnknownProvider, "unknown provider: #{name}" unless cfg
    klass = cfg[:class].constantize
    klass.new(cfg)
  end

  def default
    resolve(Scribed.config.default_provider)
  end
end

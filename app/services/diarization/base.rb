module Diarization
  class Base
    attr_reader :config

    def initialize(config = {})
      @config = config || {}
    end

    def name
      self.class.name.demodulize.underscore
    end

    def async?
      false
    end

    def submit(transcription)
      raise NotImplementedError
    end
  end
end

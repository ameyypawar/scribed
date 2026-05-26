module Providers
  Result = Data.define(:text, :language, :duration, :segments, :raw) do
    def to_h
      { text: text, language: language, duration: duration, segments: segments, raw: raw }
    end
  end
end

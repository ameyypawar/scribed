require "rails_helper"

RSpec.describe Diarization do
  describe ".resolve" do
    it "returns a Pyannote instance" do
      expect(described_class.resolve(:pyannote)).to be_a(Diarization::Pyannote)
    end

    it "raises UnknownDiarizer for unknown names" do
      expect { described_class.resolve(:nope) }.to raise_error(Diarization::UnknownDiarizer)
    end
  end

  describe ".default" do
    it "returns the configured default diarizer" do
      expect(described_class.default).to be_a(Diarization::Pyannote)
    end
  end
end

require "rails_helper"

RSpec.describe Providers do
  describe ".resolve" do
    it "returns an instance for a known provider" do
      expect(described_class.resolve(:openai_compatible)).to be_a(Providers::OpenaiCompatible)
    end

    it "accepts string names" do
      expect(described_class.resolve("openai")).to be_a(Providers::Openai)
    end

    it "raises UnknownProvider for an unregistered name" do
      expect { described_class.resolve(:nope) }.to raise_error(Providers::UnknownProvider)
    end
  end

  describe ".default" do
    it "returns the configured default provider" do
      expect(described_class.default).to be_a(Providers::OpenaiCompatible)
    end
  end
end

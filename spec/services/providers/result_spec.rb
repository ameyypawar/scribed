require "rails_helper"

RSpec.describe Providers::Result do
  let(:attrs) { { text: "hi", language: "en", duration: 1.0, segments: [], raw: {} } }

  it "exposes attributes" do
    r = described_class.new(**attrs)
    expect(r.text).to eq("hi")
    expect(r.language).to eq("en")
    expect(r.duration).to eq(1.0)
  end

  it "is value-equal" do
    expect(described_class.new(**attrs)).to eq(described_class.new(**attrs))
  end

  it "serializes via to_h" do
    expect(described_class.new(**attrs).to_h).to eq(attrs)
  end
end

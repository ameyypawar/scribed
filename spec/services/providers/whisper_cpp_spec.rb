require "rails_helper"

RSpec.describe Providers::WhisperCpp, :native do
  let(:audio) { Rails.root.join("spec/fixtures/audio/sample.wav").to_s }

  it "transcribes a short WAV" do
    skip "sample.wav missing — see spec/fixtures/audio/CREDITS.md" unless File.exist?(audio)
    result = described_class.new(model: "base.en").transcribe(audio)
    expect(result).to be_a(Providers::Result)
    expect(result.text).to be_a(String)
  end
end

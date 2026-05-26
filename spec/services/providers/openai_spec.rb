require "rails_helper"

RSpec.describe Providers::Openai do
  let(:audio) { Rails.root.join("spec/fixtures/audio/silence.wav").to_s }

  before do
    FileUtils.mkdir_p(File.dirname(audio))
    File.binwrite(audio, "RIFF\x00\x00\x00\x00WAVE") unless File.exist?(audio)
  end

  it "maps a successful response to Result" do
    stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          text: "ok",
          language: "en",
          duration: 0.5,
          segments: [{ start: 0.0, end: 0.5, text: "ok" }]
        }.to_json
      )
    result = described_class.new(api_key: "test", model: "whisper-1").transcribe(audio)
    expect(result.text).to eq("ok")
  end

  it "wraps upstream errors in ProviderError" do
    stub_request(:post, "https://api.openai.com/v1/audio/transcriptions").to_return(status: 401, body: "{}")
    expect {
      described_class.new(api_key: "test").transcribe(audio)
    }.to raise_error(Providers::ProviderError)
  end
end

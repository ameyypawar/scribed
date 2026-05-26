require "rails_helper"

RSpec.describe Providers::OpenaiCompatible do
  let(:audio) { Rails.root.join("spec/fixtures/audio/silence.wav").to_s }

  before do
    FileUtils.mkdir_p(File.dirname(audio))
    File.binwrite(audio, "RIFF\x00\x00\x00\x00WAVE") unless File.exist?(audio)

    stub_request(:post, "http://whisper:8000/v1/audio/transcriptions")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          text: "hello world",
          language: "en",
          duration: 1.23,
          segments: [{ start: 0.0, end: 1.23, text: "hello world" }]
        }.to_json
      )
  end

  it "maps response to Result" do
    result = described_class.new(base_url: "http://whisper:8000/v1").transcribe(audio)
    expect(result).to be_a(Providers::Result)
    expect(result.text).to eq("hello world")
    expect(result.segments.first["text"]).to eq("hello world")
  end

  it "raises ProviderError on 5xx" do
    stub_request(:post, "http://whisper:8000/v1/audio/transcriptions").to_return(status: 500, body: "boom")
    expect {
      described_class.new(base_url: "http://whisper:8000/v1").transcribe(audio)
    }.to raise_error(Providers::ProviderError)
  end
end

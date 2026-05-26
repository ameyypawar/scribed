require "rails_helper"

RSpec.describe Providers::Deepgram do
  let(:audio) { Rails.root.join("spec/fixtures/audio/silence.wav").to_s }

  before do
    FileUtils.mkdir_p(File.dirname(audio))
    File.binwrite(audio, "RIFF\x00\x00\x00\x00WAVE") unless File.exist?(audio)
  end

  it "sends the audio with diarization and parses speakers" do
    stub_request(:post, %r{api\.deepgram\.com/v1/listen})
      .with(headers: { "Authorization" => "Token test-key" })
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          metadata: { duration: 2.0 },
          results: {
            channels: [{
              alternatives: [{
                transcript: "hi there",
                words: [
                  { word: "hi", punctuated_word: "Hi", start: 0.0, end: 0.5, speaker: 0 },
                  { word: "there", punctuated_word: "there.", start: 0.6, end: 1.0, speaker: 1 }
                ]
              }]
            }]
          }
        }.to_json
      )

    result = described_class.new(api_key: "test-key", model: "nova-3").transcribe(audio, diarize: true)
    expect(result.text).to eq("hi there")
    expect(result.segments.length).to eq(2)
    expect(result.segments.first[:speaker]).to eq(0)
    expect(result.segments.last[:speaker]).to eq(1)
  end

  it "raises ProviderError on HTTP failure" do
    stub_request(:post, %r{api\.deepgram\.com/v1/listen}).to_return(status: 403, body: "{}")
    expect {
      described_class.new(api_key: "test-key").transcribe(audio)
    }.to raise_error(Providers::ProviderError)
  end
end

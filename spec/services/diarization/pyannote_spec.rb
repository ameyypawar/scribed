require "rails_helper"

RSpec.describe Diarization::Pyannote do
  let(:endpoint) { "https://api.pyannote.ai/v1/diarize" }
  let(:config)   { { api_key_env: "PYANNOTE_API_KEY", endpoint: endpoint } }
  subject(:diarizer) { described_class.new(config) }

  before do
    stub_const("ENV", ENV.to_hash.merge(
      "PYANNOTE_API_KEY" => "secret-key",
      "PYANNOTE_WEBHOOK_BASE_URL" => "https://scribed.example.com"
    ))
  end

  it "POSTs to pyannote endpoint with bearer auth and returns jobId" do
    record = create(:transcription, audio_url: "https://example.com/a.mp3")

    stub = stub_request(:post, endpoint)
      .with(
        headers: { "Authorization" => "Bearer secret-key", "Content-Type" => "application/json" },
        body: hash_including(
          "url" => "https://example.com/a.mp3",
          "webhook" => "https://scribed.example.com/v1/transcriptions/#{record.id}/webhook",
          "webhookId" => record.id
        )
      )
      .to_return(status: 200, body: { jobId: "job-123", status: "running" }.to_json)

    expect(diarizer.submit(record)).to eq("job-123")
    expect(stub).to have_been_requested
  end

  it "raises DiarizerError when API key is missing" do
    stub_const("ENV", ENV.to_hash.merge("PYANNOTE_API_KEY" => ""))
    record = create(:transcription, audio_url: "https://example.com/a.mp3")
    expect { diarizer.submit(record) }.to raise_error(Diarization::DiarizerError, /missing API key/)
  end

  it "raises DiarizerError when audio_url is missing" do
    record = create(:transcription, :with_attached_audio)
    expect { diarizer.submit(record) }.to raise_error(Diarization::DiarizerError, /audio_url/)
  end

  it "raises DiarizerError with status on 4xx" do
    record = create(:transcription, audio_url: "https://example.com/a.mp3")
    stub_request(:post, endpoint).to_return(status: 401, body: "nope")
    expect { diarizer.submit(record) }.to raise_error(Diarization::DiarizerError) { |e|
      expect(e.status).to eq(401)
    }
  end
end

require "rails_helper"

RSpec.describe "V1::Transcriptions", type: :request do
  let(:api_key) { "test-key-abc" }
  let(:json_headers) { { "Authorization" => "Bearer #{api_key}", "Content-Type" => "application/json" } }

  before do
    allow(Scribed.config).to receive(:api_key).and_return(api_key)
  end

  describe "POST /v1/transcriptions" do
    it "rejects without auth" do
      post "/v1/transcriptions",
           params: { audio_url: "https://example.com/y.mp3" }.to_json,
           headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("unauthorized")
    end

    it "rejects with bad token" do
      post "/v1/transcriptions",
           params: { audio_url: "https://example.com/y.mp3" }.to_json,
           headers: json_headers.merge("Authorization" => "Bearer wrong")
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates record from audio_url and enqueues job" do
      post "/v1/transcriptions",
           params: { audio_url: "https://example.com/a.mp3" }.to_json,
           headers: json_headers
      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body).to include("id", "status", "created_at")
      expect(response.headers["Location"]).to eq("/v1/transcriptions/#{body['id']}")
      expect(TranscribeJob).to have_been_enqueued.with(body["id"])
    end

    it "accepts a multipart audio upload" do
      file = Rack::Test::UploadedFile.new(StringIO.new("RIFFfake"), "audio/wav", original_filename: "s.wav")
      post "/v1/transcriptions",
           params: { audio: file },
           headers: { "Authorization" => "Bearer #{api_key}" }
      expect(response).to have_http_status(:accepted)
      record = Transcription.find(JSON.parse(response.body)["id"])
      expect(record.audio).to be_attached
    end

    it "422 when neither audio nor audio_url" do
      post "/v1/transcriptions", params: {}.to_json, headers: json_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "422 on unknown provider" do
      post "/v1/transcriptions",
           params: { audio_url: "https://x/y.mp3", provider: "nope" }.to_json,
           headers: json_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("unknown_provider")
    end

    it "422 on oversize upload" do
      allow(Scribed.config).to receive(:max_file_bytes).and_return(4)
      file = Rack::Test::UploadedFile.new(StringIO.new("RIFFtoobig"), "audio/wav", original_filename: "s.wav")
      post "/v1/transcriptions",
           params: { audio: file },
           headers: { "Authorization" => "Bearer #{api_key}" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("file_too_large")
    end

    it "stores callback_url + generates a callback_secret" do
      post "/v1/transcriptions",
           params: { audio_url: "https://x/y.mp3", callback_url: "https://you/hook" }.to_json,
           headers: json_headers
      expect(response).to have_http_status(:accepted)
      record = Transcription.find(JSON.parse(response.body)["id"])
      expect(record.webhook_url).to eq("https://you/hook")
      expect(record.callback_secret).to match(/\A[a-f0-9]{64}\z/)
    end
  end

  describe "GET /v1/transcriptions/:id" do
    it "200 with serialized body" do
      t = create(:transcription, :completed)
      get "/v1/transcriptions/#{t.id}", headers: json_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(t.id)
      expect(body["text"]).to eq("Hello, world.")
      expect(body["status"]).to eq("completed")
      expect(body["segments"]).to be_an(Array)
    end

    it "404 on missing" do
      get "/v1/transcriptions/00000000-0000-0000-0000-000000000000", headers: json_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /v1/transcriptions/:id" do
    it "204 and removes record" do
      t = create(:transcription)
      delete "/v1/transcriptions/#{t.id}", headers: json_headers
      expect(response).to have_http_status(:no_content)
      expect(Transcription.exists?(t.id)).to be false
    end
  end
end

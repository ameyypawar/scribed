require "rails_helper"

RSpec.describe "V1::TranscriptionWebhooks", type: :request do
  let(:api_key) { "test-key-abc" }
  before { allow(Scribed.config).to receive(:api_key).and_return(api_key) }

  it "returns 204 (Phase 5 will implement)" do
    t = create(:transcription)
    post "/v1/transcriptions/#{t.id}/webhook",
         headers: { "Authorization" => "Bearer #{api_key}" }
    expect(response).to have_http_status(:no_content)
  end
end

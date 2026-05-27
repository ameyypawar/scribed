require "rails_helper"

RSpec.describe "V1::TranscriptionWebhooks", type: :request do
  let(:api_key) { "test-key-abc" }
  before { allow(Scribed.config).to receive(:api_key).and_return(api_key) }

  let(:segments) do
    [
      { "start" => 0.0, "end" => 2.0, "text" => "hello" },
      { "start" => 2.0, "end" => 4.0, "text" => "world" }
    ]
  end

  let(:record) do
    create(:transcription, :completed,
           segments: segments,
           external_job_id: "job-xyz",
           webhook_url: "https://hook.example/x",
           callback_secret: "s")
  end

  def post_callback(id, body)
    post "/v1/transcriptions/#{id}/webhook",
         params: body.to_json,
         headers: { "Content-Type" => "application/json" }
  end

  it "succeeded callback merges speaker labels, marks completed, enqueues WebhookJob" do
    body = {
      jobId: "job-xyz",
      status: "succeeded",
      output: { diarization: [{ "speaker" => "SPEAKER_00", "start" => 0.0, "end" => 5.0 }] }
    }
    expect { post_callback(record.id, body) }
      .to have_enqueued_job(WebhookJob).with(record.id)
    expect(response).to have_http_status(:no_content)
    record.reload
    expect(record.status).to eq("completed")
    expect(record.diarization).to eq([{ "speaker" => "SPEAKER_00", "start" => 0.0, "end" => 5.0 }])
    expect(record.segments.first["speaker"]).to eq("SPEAKER_00")
  end

  it "failed callback marks record failed and enqueues WebhookJob" do
    body = { jobId: "job-xyz", status: "failed", error: "boom" }
    expect { post_callback(record.id, body) }
      .to have_enqueued_job(WebhookJob).with(record.id)
    record.reload
    expect(record.status).to eq("failed")
    expect(record.error_message).to eq("boom")
  end

  it "returns 422 on jobId mismatch" do
    post_callback(record.id, { jobId: "wrong", status: "succeeded", output: { diarization: [] } })
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "returns 404 for unknown record id" do
    post_callback("00000000-0000-0000-0000-000000000000",
                  { jobId: "x", status: "succeeded", output: { diarization: [] } })
    expect(response).to have_http_status(:not_found)
  end

  it "does not require bearer auth" do
    body = { jobId: "job-xyz", status: "succeeded", output: { diarization: [] } }
    post_callback(record.id, body)
    expect(response).to have_http_status(:no_content)
  end
end

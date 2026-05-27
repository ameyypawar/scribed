require "rails_helper"

RSpec.describe WebhookJob do
  let(:url) { "https://hook.example/incoming" }

  before do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    allow(Scribed.config).to receive(:webhook_secret).and_return("global-secret")
  end

  def perform!(record)
    described_class.new.perform(record.id)
  end

  it "POSTs JSON with signed headers for a completed record" do
    record = create(:transcription, :completed,
                    webhook_url: url,
                    callback_secret: "per-record-secret")

    captured = nil
    stub_request(:post, url).with { |req| captured = req; true }
      .to_return(status: 200, body: "")

    perform!(record)

    expect(captured.headers["Content-Type"]).to eq("application/json")
    expect(captured.headers["X-Scribed-Event"]).to eq("transcription.completed")
    expect(captured.headers["User-Agent"]).to eq("scribed/0.1")
    sig = captured.headers["X-Scribed-Signature"]
    expect(sig).to start_with("sha256=")
    expect(WebhookSigner.verify(body: captured.body, signature: sig, secret: "per-record-secret")).to be true

    parsed = JSON.parse(captured.body)
    expect(parsed["event"]).to eq("transcription.completed")
    expect(parsed["id"]).to eq(record.id)
    expect(parsed["text"]).to eq("Hello, world.")
  end

  it "increments webhook_attempts" do
    record = create(:transcription, :completed, webhook_url: url, callback_secret: "s")
    stub_request(:post, url).to_return(status: 200, body: "")
    expect { perform!(record) }.to change { record.reload.webhook_attempts }.by(1)
  end

  it "raises DeliveryError on 5xx so Sidekiq retries" do
    record = create(:transcription, :completed, webhook_url: url, callback_secret: "s")
    stub_request(:post, url).to_return(status: 503, body: "")
    expect { perform!(record) }.to raise_error(WebhookJob::DeliveryError, /503/)
  end

  it "is a no-op when webhook_url is blank" do
    record = create(:transcription, :completed)
    record.update_columns(webhook_url: nil, callback_secret: nil)
    perform!(record)
    expect(WebMock).not_to have_requested(:post, /.*/)
    expect(record.reload.webhook_attempts).to eq(0)
  end

  it "falls back to Scribed.config.webhook_secret when callback_secret blank" do
    record = create(:transcription, :failed, webhook_url: url)
    record.update_columns(callback_secret: nil)

    captured = nil
    stub_request(:post, url).with { |req| captured = req; true }
      .to_return(status: 200, body: "")

    perform!(record)

    sig = captured.headers["X-Scribed-Signature"]
    expect(WebhookSigner.verify(body: captured.body, signature: sig, secret: "global-secret")).to be true
    expect(captured.headers["X-Scribed-Event"]).to eq("transcription.failed")
  end
end

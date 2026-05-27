require "rails_helper"

RSpec.describe TranscribeJob do
  let(:result) do
    Providers::Result.new(
      text: "Hello world",
      language: "en",
      duration: 2.5,
      segments: [{ "start" => 0.0, "end" => 2.5, "text" => "Hello world" }],
      raw: { "ok" => true }
    )
  end

  let(:provider) do
    instance_double(Providers::OpenaiCompatible,
                    transcribe: result,
                    supports_diarization?: false)
  end

  before do
    allow(Providers).to receive(:resolve).and_return(provider)
    allow(AudioFetcher).to receive(:with_local_file).and_yield("/tmp/fake.wav")
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  it "transitions pending → processing → completed and persists result" do
    record = create(:transcription)
    described_class.perform_now(record.id)
    record.reload
    expect(record.status).to eq("completed")
    expect(record.transcript).to eq("Hello world")
    expect(record.language).to eq("en")
    expect(record.audio_duration_seconds).to eq(2)
    expect(record.processing_started_at).to be_present
    expect(record.processing_completed_at).to be_present
  end

  it "enqueues WebhookJob when webhook_url present" do
    record = create(:transcription, webhook_url: "https://hook.example/x", callback_secret: "s")
    expect {
      described_class.perform_now(record.id)
    }.to have_enqueued_job(WebhookJob).with(record.id).on_queue("webhooks")
  end

  it "does not enqueue WebhookJob when webhook_url blank" do
    record = create(:transcription)
    expect {
      described_class.perform_now(record.id)
    }.not_to have_enqueued_job(WebhookJob)
  end

  it "skips when record is not pending" do
    record = create(:transcription, :completed)
    described_class.perform_now(record.id)
    record.reload
    expect(record.status).to eq("completed")
    expect(provider).not_to have_received(:transcribe)
  end

  context "on ProviderError" do
    before do
      allow(provider).to receive(:transcribe).and_raise(
        Providers::ProviderError.new("openai: HTTP 401", status: 401, body: "nope")
      )
    end

    it "marks failed, enqueues webhook, and does not retry" do
      record = create(:transcription, webhook_url: "https://hook.example/x", callback_secret: "s")
      expect {
        described_class.perform_now(record.id)
      }.to have_enqueued_job(WebhookJob).with(record.id)
      record.reload
      expect(record.status).to eq("failed")
      expect(record.error_message).to match(/HTTP 401/)
    end
  end

  context "on AudioFetcher::FetchError" do
    before do
      allow(AudioFetcher).to receive(:with_local_file)
        .and_raise(AudioFetcher::FetchError, "boom")
    end

    # retry_on uses rescue_from internally; in Rails 8.1 + test adapter, the job is
    # re-enqueued for retry without propagating the exception to the caller of perform_now.
    it "marks failed, enqueues webhook, and schedules retry" do
      record = create(:transcription, webhook_url: "https://hook.example/x", callback_secret: "s")
      described_class.perform_now(record.id)
      record.reload
      expect(record.status).to eq("failed")
      expect(record.error_message).to eq("boom")
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.map { |j| j[:job] }).to include(WebhookJob)
    end
  end
end

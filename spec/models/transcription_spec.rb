require "rails_helper"

RSpec.describe Transcription, type: :model do
  describe "validations" do
    it "is valid with a pending status and openai_compatible provider" do
      t = build(:transcription)
      expect(t).to be_valid
    end

    it "rejects an unknown status" do
      t = build(:transcription, status: "bogus")
      expect(t).not_to be_valid
    end

    it "rejects an unknown provider" do
      t = build(:transcription, provider: "unknown_provider")
      expect(t).not_to be_valid
    end
  end

  describe "scopes" do
    before do
      create(:transcription, :completed)
      create(:transcription, :failed)
      create(:transcription)
    end

    it "returns completed transcriptions" do
      expect(Transcription.completed.count).to eq(1)
    end

    it "returns pending transcriptions" do
      expect(Transcription.pending.count).to eq(1)
    end
  end

  describe "#mark_processing!" do
    it "transitions status and records start time" do
      t = create(:transcription)
      t.mark_processing!
      expect(t.reload.status).to eq("processing")
      expect(t.processing_started_at).not_to be_nil
    end
  end

  describe "#mark_completed!" do
    it "stores the transcript and marks completed" do
      t = create(:transcription, :processing)
      t.mark_completed!(transcript: "test output", metadata: { "model" => "whisper-1" })
      t.reload
      expect(t.status).to eq("completed")
      expect(t.transcript).to eq("test output")
      expect(t.provider_metadata["model"]).to eq("whisper-1")
    end
  end

  describe "#mark_failed!" do
    it "records the error message" do
      t = create(:transcription, :processing)
      t.mark_failed!(StandardError.new("boom"))
      expect(t.reload.status).to eq("failed")
      expect(t.error_message).to eq("boom")
    end
  end
end

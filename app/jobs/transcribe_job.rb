class TranscribeJob < ApplicationJob
  queue_as :default

  def perform(transcription_id)
    Rails.logger.info("[TranscribeJob] enqueued for #{transcription_id} (Phase 4 will implement)")
  end
end

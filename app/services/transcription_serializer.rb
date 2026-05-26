class TranscriptionSerializer
  def self.call(record, view: :full)
    new(record).public_send(view)
  end

  def initialize(record)
    @r = record
  end

  def minimal
    { id: @r.id, status: @r.status, created_at: @r.created_at }
  end

  def full
    payload = {
      id: @r.id,
      status: @r.status,
      provider: @r.provider,
      model: @r.model,
      language: @r.language,
      text: @r.transcript,
      duration_seconds: @r.audio_duration_seconds,
      segments: @r.segments,
      diarization: @r.diarization,
      audio_url: attached_url || @r.audio_url,
      callback_url: @r.webhook_url,
      created_at: @r.created_at,
      updated_at: @r.updated_at,
      error: @r.error_message
    }
    payload.delete(:callback_url) if payload[:callback_url].blank?
    payload
  end

  private

  def attached_url
    return nil unless @r.audio.attached?
    Rails.application.routes.url_helpers.rails_blob_url(@r.audio, only_path: true)
  rescue StandardError
    nil
  end
end

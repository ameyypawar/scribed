class Transcription < ApplicationRecord
  has_one_attached :audio

  STATUSES  = %w[pending processing completed failed cancelled].freeze
  PROVIDERS = %w[openai openai_compatible whisper_cpp deepgram].freeze

  validates :status,   inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: PROVIDERS }
  validate  :audio_source_present

  scope :pending,    -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :completed,  -> { where(status: "completed") }
  scope :failed,     -> { where(status: "failed") }
  scope :cancelled,  -> { where(status: "cancelled") }
  scope :terminal,   -> { where(status: %w[completed failed cancelled]) }

  def pending?     = status == "pending"
  def processing?  = status == "processing"
  def completed?   = status == "completed"
  def failed?      = status == "failed"
  def cancelled?   = status == "cancelled"

  def mark_processing!
    update!(status: "processing", processing_started_at: Time.current.to_i)
  end

  def mark_completed!(transcript:, metadata: {}, segments: nil, diarization: nil, language: nil, duration: nil)
    attrs = {
      status: "completed",
      transcript: transcript,
      provider_metadata: metadata,
      processing_completed_at: Time.current.to_i
    }
    attrs[:segments] = segments if segments
    attrs[:diarization] = diarization if diarization
    attrs[:language] = language if language
    attrs[:audio_duration_seconds] = duration if duration
    update!(attrs)
  end

  def mark_failed!(error)
    update!(status: "failed", error_message: error.to_s)
  end

  def mark_cancelled!
    update!(status: "cancelled")
  end

  private

  def audio_source_present
    return if audio.attached? || audio_url.present?
    errors.add(:base, "must provide either audio attachment or audio_url")
  end
end

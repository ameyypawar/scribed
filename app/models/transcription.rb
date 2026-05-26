class Transcription < ApplicationRecord
  has_one_attached :audio

  STATUSES  = %w[pending processing completed failed].freeze
  PROVIDERS = %w[openai_compatible deepgram].freeze

  validates :status,   inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: PROVIDERS }

  scope :pending,    -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :completed,  -> { where(status: "completed") }
  scope :failed,     -> { where(status: "failed") }

  def pending?    = status == "pending"
  def processing? = status == "processing"
  def completed?  = status == "completed"
  def failed?     = status == "failed"

  def mark_processing!
    update!(status: "processing", processing_started_at: Time.current.to_i)
  end

  def mark_completed!(transcript:, metadata: {})
    update!(
      status: "completed",
      transcript: transcript,
      provider_metadata: metadata,
      processing_completed_at: Time.current.to_i
    )
  end

  def mark_failed!(error)
    update!(status: "failed", error_message: error.to_s)
  end
end

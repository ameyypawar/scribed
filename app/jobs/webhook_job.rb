require "faraday"
require "json"

class WebhookJob < ApplicationJob
  queue_as :webhooks

  EVENT_MAP = {
    "completed" => "transcription.completed",
    "failed"    => "transcription.failed",
    "cancelled" => "transcription.cancelled"
  }.freeze

  USER_AGENT = "scribed/0.1".freeze

  class DeliveryError < StandardError; end

  retry_on DeliveryError, wait: :polynomially_longer, attempts: 5

  def perform(transcription_id)
    record = Transcription.find(transcription_id)

    if record.webhook_url.blank?
      Rails.logger.info("[WebhookJob] skipped #{transcription_id}: no webhook_url")
      return
    end

    event = EVENT_MAP[record.status]
    unless event
      Rails.logger.info("[WebhookJob] skipped #{transcription_id}: non-terminal status #{record.status}")
      return
    end

    payload = TranscriptionSerializer.call(record, view: :full).merge(event: event)
    body = JSON.generate(payload)
    secret = record.callback_secret.presence || Scribed.config.webhook_secret
    signature = WebhookSigner.sign(body: body, secret: secret)

    record.increment!(:webhook_attempts)

    response = Faraday.post(record.webhook_url) do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["X-Scribed-Signature"] = signature
      req.headers["X-Scribed-Event"] = event
      req.headers["User-Agent"] = USER_AGENT
      req.body = body
    end

    if response.status >= 200 && response.status < 300
      Rails.logger.info("[WebhookJob] delivered #{transcription_id} → #{record.webhook_url} (#{response.status})")
    else
      raise DeliveryError, "webhook POST returned #{response.status}"
    end
  rescue Faraday::Error => e
    raise DeliveryError, "webhook POST failed: #{e.message}"
  end
end

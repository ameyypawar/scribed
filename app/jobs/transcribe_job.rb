class TranscribeJob < ApplicationJob
  queue_as :transcriptions

  discard_on Providers::ProviderError do |job, error|
    record = Transcription.find_by(id: job.arguments.first)
    next unless record
    record.mark_failed!(error.message) unless record.failed?
    WebhookJob.perform_later(record.id) if record.webhook_url.present?
  end

  retry_on AudioFetcher::FetchError, wait: :polynomially_longer, attempts: 3

  def perform(transcription_id)
    record = Transcription.find(transcription_id)

    unless record.pending?
      Rails.logger.info("[TranscribeJob] skipping #{transcription_id}: status=#{record.status}")
      return
    end

    record.mark_processing!
    provider = Providers.resolve(record.provider)

    AudioFetcher.with_local_file(record) do |path|
      opts = build_opts(record)
      result = provider.transcribe(path, **opts)

      diarization_segments =
        if provider.supports_diarization? && opts[:diarize]
          Array(result.segments)
        else
          []
        end

      record.mark_completed!(
        transcript: result.text,
        metadata: result.raw,
        segments: Array(result.segments),
        diarization: diarization_segments,
        language: result.language,
        duration: result.duration
      )
    end

    if needs_sidecar_diarization?(record, provider)
      submit_sidecar_diarization!(record)
    elsif record.webhook_url.present?
      WebhookJob.perform_later(record.id)
    end
  rescue Providers::ProviderError
    raise
  rescue AudioFetcher::FetchError => e
    record&.mark_failed!(e.message)
    WebhookJob.perform_later(record.id) if record&.webhook_url.present?
    raise
  rescue StandardError => e
    record&.mark_failed!(e.message)
    WebhookJob.perform_later(record.id) if record&.webhook_url.present?
    raise
  end

  private

  def build_opts(record)
    {
      model: record.model,
      language: record.language,
      prompt: record.prompt,
      temperature: record.temperature,
      diarize: record.diarize
    }.compact
  end

  def needs_sidecar_diarization?(record, provider)
    record.diarize && !provider.supports_diarization?
  end

  def submit_sidecar_diarization!(record)
    diarizer = Diarization.default
    external_job_id = diarizer.submit(record)
    record.update!(external_job_id: external_job_id, status: "processing")
  rescue Diarization::DiarizerError => e
    record.mark_failed!(e.message)
    WebhookJob.perform_later(record.id) if record.webhook_url.present?
  end
end

module V1
  class TranscriptionsController < BaseController
    PERMITTED = %i[audio audio_url provider model language diarize
                   callback_url submitted_by prompt temperature].freeze

    def create
      params_hash = transcription_params

      audio_file   = params_hash.delete(:audio)
      callback_url = params_hash.delete(:callback_url)
      provider_name = params_hash[:provider].presence || Scribed.config.default_provider.to_s

      Providers.resolve(provider_name)
      params_hash[:provider] = provider_name

      if audio_file.respond_to?(:size) && audio_file.size > Scribed.config.max_file_bytes
        return render_error(code: "file_too_large",
                            message: "audio exceeds #{Scribed.config.max_file_bytes} bytes",
                            status: :unprocessable_entity)
      end

      record = Transcription.new(params_hash.merge(status: "pending"))
      if callback_url.present?
        record.webhook_url = callback_url
        record.callback_secret = SecureRandom.hex(32)
      end
      record.audio.attach(audio_file) if audio_file.respond_to?(:read)

      record.save!
      TranscribeJob.perform_later(record.id)

      response.headers["Location"] = "/v1/transcriptions/#{record.id}"
      render json: TranscriptionSerializer.call(record, view: :minimal), status: :accepted
    end

    def show
      record = Transcription.find(params[:id])
      render json: TranscriptionSerializer.call(record)
    end

    def destroy
      record = Transcription.find(params[:id])
      record.audio.purge if record.audio.attached?
      record.destroy!
      head :no_content
    end

    private

    def transcription_params
      raw = params.permit(*PERMITTED)
      raw[:diarize] = ActiveModel::Type::Boolean.new.cast(raw[:diarize]) if raw.key?(:diarize)
      raw[:temperature] = raw[:temperature].to_f if raw[:temperature].present?
      raw.to_h.symbolize_keys
    end
  end
end

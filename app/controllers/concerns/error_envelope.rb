module ErrorEnvelope
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound do |e|
      render_error(code: "not_found", message: e.message, status: :not_found)
    end
    rescue_from ActiveRecord::RecordInvalid do |e|
      render_error(code: "invalid_record",
                   message: e.record.errors.full_messages.join(", "),
                   status: :unprocessable_entity,
                   details: e.record.errors.as_json)
    end
    rescue_from Providers::UnknownProvider do |e|
      render_error(code: "unknown_provider", message: e.message, status: :unprocessable_entity)
    end
    rescue_from ActionController::ParameterMissing do |e|
      render_error(code: "parameter_missing", message: e.message, status: :unprocessable_entity)
    end
  end

  private

  def render_error(code:, message:, status:, details: nil)
    payload = { error: { code: code, message: message } }
    payload[:error][:details] = details if details
    render json: payload, status: status
  end
end

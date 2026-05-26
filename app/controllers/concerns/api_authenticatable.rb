module ApiAuthenticatable
  extend ActiveSupport::Concern

  @auth_disabled_warned = false

  class << self
    attr_accessor :auth_disabled_warned
  end

  private

  def authenticate!
    expected = Scribed.config.api_key
    if expected.blank?
      unless ApiAuthenticatable.auth_disabled_warned
        Rails.logger.warn("[scribed] SCRIBED_API_KEY is blank; bearer auth disabled (dev only)")
        ApiAuthenticatable.auth_disabled_warned = true
      end
      return
    end

    header = request.headers["Authorization"].to_s
    presented = header.start_with?("Bearer ") ? header.sub("Bearer ", "") : ""

    return if presented.present? &&
              ActiveSupport::SecurityUtils.secure_compare(presented, expected)

    render json: {
      error: { code: "unauthorized", message: "missing or invalid bearer token" }
    }, status: :unauthorized
  end
end

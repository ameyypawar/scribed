module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :token

    def connect
      self.token = find_token
      expected = Scribed.config.api_key
      return if expected.blank?
      reject_unauthorized_connection unless token.present? &&
        ActiveSupport::SecurityUtils.secure_compare(token, expected)
    end

    private

    def find_token
      header = request.headers["Authorization"].to_s
      return header.sub("Bearer ", "") if header.start_with?("Bearer ")
      request.params[:token].to_s
    end
  end
end

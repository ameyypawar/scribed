require "openssl"
require "active_support/security_utils"

class WebhookSigner
  ALGO = "SHA256".freeze
  PREFIX = "sha256=".freeze

  def self.sign(body:, secret:)
    raise ArgumentError, "secret required" if secret.to_s.empty?
    digest = OpenSSL::HMAC.hexdigest(ALGO, secret.to_s, body.to_s)
    "#{PREFIX}#{digest}"
  end

  def self.verify(body:, signature:, secret:)
    return false if signature.to_s.empty? || secret.to_s.empty?
    expected = sign(body: body, secret: secret)
    ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
  end
end

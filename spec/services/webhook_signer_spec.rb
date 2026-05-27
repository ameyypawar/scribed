require "rails_helper"

RSpec.describe WebhookSigner do
  let(:body) { '{"event":"transcription.completed","id":"abc"}' }
  let(:secret) { "shhh-it-is-a-secret" }

  describe ".sign" do
    it "produces a deterministic sha256= hex digest" do
      sig1 = described_class.sign(body: body, secret: secret)
      sig2 = described_class.sign(body: body, secret: secret)
      expect(sig1).to eq(sig2)
      expect(sig1).to start_with("sha256=")
      expect(sig1.sub("sha256=", "")).to match(/\A[0-9a-f]{64}\z/)
    end

    it "matches a hand-computed HMAC-SHA256" do
      expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, body)
      expect(described_class.sign(body: body, secret: secret)).to eq(expected)
    end

    it "raises when secret is blank" do
      expect { described_class.sign(body: body, secret: "") }.to raise_error(ArgumentError)
    end
  end

  describe ".verify" do
    it "returns true for a matching signature" do
      sig = described_class.sign(body: body, secret: secret)
      expect(described_class.verify(body: body, signature: sig, secret: secret)).to be true
    end

    it "returns false for a tampered body" do
      sig = described_class.sign(body: body, secret: secret)
      expect(described_class.verify(body: body + "!", signature: sig, secret: secret)).to be false
    end

    it "returns false for a wrong secret" do
      sig = described_class.sign(body: body, secret: secret)
      expect(described_class.verify(body: body, signature: sig, secret: "other")).to be false
    end

    it "returns false when signature is empty" do
      expect(described_class.verify(body: body, signature: "", secret: secret)).to be false
    end
  end
end

require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:api_key) { "test-secret-key" }

  context "when api_key is configured" do
    before { allow(Scribed.config).to receive(:api_key).and_return(api_key) }

    it "connects with a valid bearer token" do
      connect "/cable", headers: { "Authorization" => "Bearer #{api_key}" }
      expect(connection.token).to eq(api_key)
    end

    it "rejects when bearer token is missing" do
      expect { connect "/cable" }.to have_rejected_connection
    end

    it "rejects when bearer token is wrong" do
      expect { connect "/cable", headers: { "Authorization" => "Bearer nope" } }
        .to have_rejected_connection
    end

    it "accepts the token via the ?token= query param" do
      connect "/cable?token=#{api_key}"
      expect(connection.token).to eq(api_key)
    end
  end

  context "when api_key is blank (dev mode)" do
    before { allow(Scribed.config).to receive(:api_key).and_return(nil) }

    it "connects without any credentials" do
      connect "/cable"
      expect(connection).to be_present
    end
  end
end

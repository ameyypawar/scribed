require "rails_helper"

RSpec.describe TranscriptionChannel, type: :channel do
  before do
    allow(Scribed.config).to receive(:api_key).and_return(nil)
    stub_connection token: nil
  end

  it "rejects the subscription and transmits not_implemented" do
    subscribe
    expect(subscription).to be_rejected
    expect(transmissions.last).to include(
      "event" => "error",
      "code"  => "not_implemented"
    )
  end
end

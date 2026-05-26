require "vcr"
require "webmock/rspec"

VCR.configure do |c|
  c.cassette_library_dir = Rails.root.join("spec/fixtures/vcr_cassettes").to_s
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.filter_sensitive_data("<OPENAI_API_KEY>") { ENV["OPENAI_API_KEY"] }
  c.filter_sensitive_data("<DEEPGRAM_API_KEY>") { ENV["DEEPGRAM_API_KEY"] }
  c.filter_sensitive_data("<PYANNOTE_API_KEY>") { ENV["PYANNOTE_API_KEY"] }
  c.default_cassette_options = { record: :new_episodes, match_requests_on: [:method, :uri, :body] }
end

WebMock.disable_net_connect!(allow_localhost: true)

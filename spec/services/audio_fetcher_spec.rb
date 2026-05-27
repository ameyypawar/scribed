require "rails_helper"

RSpec.describe AudioFetcher do
  describe ".with_local_file" do
    context "with attached audio" do
      let(:record) { create(:transcription, :with_attached_audio) }

      it "yields a local path to the blob contents" do
        yielded = nil
        described_class.with_local_file(record) do |path|
          yielded = path
          expect(File.exist?(path)).to be true
          expect(File.read(path)).to eq("fake-audio-bytes")
        end
        expect(yielded).to be_a(String)
      end
    end

    context "with audio_url" do
      let(:url) { "https://example.com/sample.mp3" }
      let(:record) { create(:transcription, audio_url: url) }

      it "downloads via Down and yields the tempfile path" do
        stub_request(:get, url).to_return(status: 200, body: "remote-bytes", headers: { "Content-Type" => "audio/mpeg" })

        described_class.with_local_file(record) do |path|
          expect(File.read(path)).to eq("remote-bytes")
        end
      end

      it "raises FetchError on 404" do
        stub_request(:get, url).to_return(status: 404, body: "not found")

        expect {
          described_class.with_local_file(record) { |_| }
        }.to raise_error(AudioFetcher::FetchError, /not found/i)
      end

      it "raises FetchError when size cap exceeded" do
        allow(Scribed.config).to receive(:max_file_bytes).and_return(10)
        big = "x" * 1024
        stub_request(:get, url).to_return(
          status: 200,
          body: big,
          headers: { "Content-Type" => "audio/mpeg", "Content-Length" => big.bytesize.to_s }
        )

        expect {
          described_class.with_local_file(record) { |_| }
        }.to raise_error(AudioFetcher::FetchError, /exceeds max size/i)
      end
    end
  end
end

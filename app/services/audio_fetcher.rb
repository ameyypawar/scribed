require "down"

class AudioFetcher
  class FetchError < StandardError; end

  def self.with_local_file(record, &block)
    new(record).with_local_file(&block)
  end

  def initialize(record)
    @record = record
  end

  def with_local_file
    if @record.audio.attached?
      @record.audio.open do |tempfile|
        yield tempfile.path
      end
    elsif @record.audio_url.present?
      tempfile = download_remote(@record.audio_url)
      begin
        yield tempfile.path
      ensure
        tempfile.close
        tempfile.unlink if tempfile.respond_to?(:unlink)
      end
    else
      raise FetchError, "transcription #{@record.id} has neither attached audio nor audio_url"
    end
  rescue ActiveStorage::FileNotFoundError => e
    raise FetchError, "attached audio missing from storage: #{e.message}"
  end

  private

  def download_remote(url)
    Down.download(url, max_size: Scribed.config.max_file_bytes)
  rescue Down::TooLarge => e
    raise FetchError, "audio_url exceeds max size #{Scribed.config.max_file_bytes} bytes: #{e.message}"
  rescue Down::NotFound => e
    raise FetchError, "audio_url not found (404): #{e.message}"
  rescue Down::Error => e
    raise FetchError, "failed to download audio_url: #{e.message}"
  end
end

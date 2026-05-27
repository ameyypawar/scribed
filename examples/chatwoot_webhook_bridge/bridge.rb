require "sinatra/base"
require "faraday"
require "json"
require "openssl"

class Bridge < Sinatra::Base
  CHATWOOT_BASE_URL     = ENV.fetch("CHATWOOT_BASE_URL", "http://localhost:3000")
  CHATWOOT_API_TOKEN    = ENV.fetch("CHATWOOT_API_TOKEN")
  CHATWOOT_HMAC_SECRET  = ENV.fetch("CHATWOOT_HMAC_SECRET", "")
  SCRIBED_URL           = ENV.fetch("SCRIBED_URL", "http://localhost:3000")
  SCRIBED_API_KEY       = ENV.fetch("SCRIBED_API_KEY", "change-me-dev-key")
  SCRIBED_WEBHOOK_SECRET = ENV.fetch("SCRIBED_WEBHOOK_SECRET", "change-me-webhook-secret")
  BRIDGE_PUBLIC_URL     = ENV.fetch("BRIDGE_PUBLIC_URL", "http://localhost:4567")

  # In-memory map: scribed transcription_id => {account_id, conversation_id, message_id}
  # (Production: use Redis or a db. This is a demo.)
  @@correlations = {}

  post "/chatwoot/webhook" do
    raw = request.body.read
    verify_chatwoot_signature!(raw, request.env["HTTP_X_CHATWOOT_SIGNATURE"]) unless CHATWOOT_HMAC_SECRET.empty?
    payload = JSON.parse(raw)

    return [200, {}, ""] unless payload["event"] == "message_created"
    return [200, {}, ""] if payload["message_type"] != "incoming"

    audio = (payload["attachments"] || []).find { |a| %w[audio file].include?(a["file_type"]) && audio_mime?(a) }
    return [200, {}, ""] unless audio

    submission = submit_to_scribed(audio["data_url"])
    transcription_id = submission["id"]
    @@correlations[transcription_id] = {
      account_id: payload.dig("account", "id"),
      conversation_id: payload.dig("conversation", "id"),
      original_message_id: payload["id"]
    }

    logger.info("[bridge] submitted message=#{payload['id']} => scribed=#{transcription_id}")
    [202, { "Content-Type" => "application/json" }, JSON.generate(transcription_id: transcription_id)]
  end

  post "/scribed/callback" do
    raw = request.body.read
    verify_scribed_signature!(raw, request.env["HTTP_X_SCRIBED_SIGNATURE"])
    payload = JSON.parse(raw)
    id = payload["id"]
    correlation = @@correlations.delete(id)
    halt 404, "unknown transcription_id" unless correlation

    case payload["event"]
    when "transcription.completed"
      post_private_note(correlation, format_transcript(payload))
    when "transcription.failed"
      post_private_note(correlation, "Transcription failed: #{payload['error']}")
    else
      logger.info("[bridge] ignoring event #{payload['event']}")
    end

    [204, {}, ""]
  end

  get "/health" do
    [200, { "Content-Type" => "application/json" }, JSON.generate(ok: true)]
  end

  helpers do
    def audio_mime?(attachment)
      mime = attachment["content_type"].to_s
      mime.start_with?("audio/") ||
        attachment["data_url"].to_s.match?(/\.(mp3|m4a|wav|ogg|webm|flac|mp4|mpeg|mpga)$/i)
    end

    def submit_to_scribed(audio_url)
      response = scribed_client.post("/v1/transcriptions") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = JSON.generate(
          audio_url: audio_url,
          provider: "openai_compatible",
          callback_url: "#{BRIDGE_PUBLIC_URL.chomp('/')}/scribed/callback"
        )
      end
      raise "scribed submit failed: #{response.status} #{response.body}" if response.status >= 400
      JSON.parse(response.body)
    end

    def post_private_note(correlation, body)
      chatwoot_client.post(
        "/api/v1/accounts/#{correlation[:account_id]}/conversations/#{correlation[:conversation_id]}/messages"
      ) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = JSON.generate(content: body, message_type: "outgoing", private: true)
      end
    end

    def format_transcript(payload)
      text = payload["text"].to_s.strip
      lang = payload["language"]
      duration = payload["duration_seconds"]
      segments = payload["segments"] || []
      speakers = segments.flat_map { |s| s["speaker"] }.compact.uniq

      header = ["🗣️ Transcription"]
      header << "  • language: #{lang}" if lang
      header << "  • duration: #{duration}s" if duration
      header << "  • speakers: #{speakers.join(', ')}" unless speakers.empty?

      ([header.join("\n"), "", text].join("\n"))
    end

    def verify_chatwoot_signature!(body, presented)
      expected = OpenSSL::HMAC.hexdigest("SHA256", CHATWOOT_HMAC_SECRET, body)
      halt 401, "invalid chatwoot signature" unless secure_compare(expected, presented.to_s)
    end

    def verify_scribed_signature!(body, presented)
      expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", SCRIBED_WEBHOOK_SECRET, body)
      halt 401, "invalid scribed signature" unless secure_compare(expected, presented.to_s)
    end

    def secure_compare(a, b)
      return false if a.bytesize != b.bytesize
      a.unpack("C*").zip(b.unpack("C*")).reduce(0) { |acc, (x, y)| acc | (x ^ y) }.zero?
    end

    def scribed_client
      @scribed_client ||= Faraday.new(url: SCRIBED_URL) do |f|
        f.request :authorization, "Bearer", SCRIBED_API_KEY
      end
    end

    def chatwoot_client
      @chatwoot_client ||= Faraday.new(url: CHATWOOT_BASE_URL) do |f|
        f.headers["api_access_token"] = CHATWOOT_API_TOKEN
      end
    end
  end

  run! if app_file == $PROGRAM_NAME
end

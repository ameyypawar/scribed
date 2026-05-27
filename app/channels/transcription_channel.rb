# WebSocket entrypoint for live transcription. Full implementation deferred to v0.3.
# See docs/streaming.md for protocol + architecture.
class TranscriptionChannel < ApplicationCable::Channel
  def subscribed
    transmit({ event: "error", code: "not_implemented",
               message: "live streaming not yet implemented — see docs/streaming.md" })
    reject
  end

  def receive(_data)
    transmit({ event: "error", code: "not_implemented",
               message: "live streaming not yet implemented — see docs/streaming.md" })
  end
end

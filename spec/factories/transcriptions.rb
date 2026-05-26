FactoryBot.define do
  factory :transcription do
    status    { "pending" }
    provider  { "openai_compatible" }
    audio_url { "https://example.com/audio.mp3" }

    trait :with_attached_audio do
      audio_url { nil }
      after(:build) do |t|
        t.audio.attach(
          io: StringIO.new("fake-audio-bytes"),
          filename: "sample.mp3",
          content_type: "audio/mpeg"
        )
      end
    end

    trait :processing do
      status                { "processing" }
      processing_started_at { Time.current.to_i }
    end

    trait :completed do
      status                  { "completed" }
      transcript              { "Hello, world." }
      language                { "en" }
      audio_duration_seconds  { 2 }
      segments                { [{ "start" => 0.0, "end" => 2.0, "text" => "Hello, world." }] }
      processing_started_at   { 10.seconds.ago.to_i }
      processing_completed_at { Time.current.to_i }
    end

    trait :failed do
      status        { "failed" }
      error_message { "Provider timeout" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end

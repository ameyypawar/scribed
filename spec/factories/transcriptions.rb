FactoryBot.define do
  factory :transcription do
    status   { "pending" }
    provider { "openai_compatible" }

    trait :processing do
      status { "processing" }
      processing_started_at { Time.current.to_i }
    end

    trait :completed do
      status                  { "completed" }
      transcript              { "Hello, world." }
      processing_started_at   { 10.seconds.ago.to_i }
      processing_completed_at { Time.current.to_i }
    end

    trait :failed do
      status        { "failed" }
      error_message { "Provider timeout" }
    end
  end
end

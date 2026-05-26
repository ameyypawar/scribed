class CreateTranscriptions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :transcriptions, id: :uuid do |t|
      t.string  :status,        null: false, default: "pending"
      t.string  :provider,      null: false, default: "openai_compatible"
      t.string  :language
      t.string  :audio_filename
      t.integer :audio_duration_seconds
      t.text    :transcript
      t.text    :error_message
      t.jsonb   :provider_metadata, null: false, default: {}
      t.string  :webhook_url
      t.integer :webhook_attempts, null: false, default: 0
      t.integer :processing_started_at
      t.integer :processing_completed_at

      t.timestamps
    end

    add_index :transcriptions, :status
    add_index :transcriptions, :created_at
  end
end

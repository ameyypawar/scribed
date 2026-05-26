class AddApiFieldsToTranscriptions < ActiveRecord::Migration[8.1]
  def change
    change_table :transcriptions, bulk: true do |t|
      t.string  :audio_url
      t.string  :model
      t.boolean :diarize,         null: false, default: false
      t.string  :submitted_by
      t.text    :prompt
      t.float   :temperature
      t.string  :callback_secret
      t.string  :external_job_id
      t.jsonb   :segments,        null: false, default: []
      t.jsonb   :diarization,     null: false, default: []
    end

    add_index :transcriptions, :external_job_id
  end
end

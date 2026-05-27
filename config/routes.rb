Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount ActionCable.server => "/cable"

  scope :v1, defaults: { format: :json } do
    resources :transcriptions, only: [:create, :show, :destroy], controller: "v1/transcriptions"
    post "transcriptions/:id/webhook",
         to: "v1/transcription_webhooks#receive",
         as: :transcription_webhook
  end
end

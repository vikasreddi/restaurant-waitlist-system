Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Bootstrap-phase health check consumed by the frontend (Phase 5A). Returns JSON, not just 200.
  get "health" => "health#show"

  # Guest-facing join + current-status endpoints — match the routes already
  # defined in documents/05-specifications/api-spec.md; not a new URL structure.
  namespace :guest do
    resources :queue_entries, only: [:create], path: "queue-entries" do
      collection do
        get :current
        post "current/leave", to: "queue_entries#leave"
      end
    end
  end

  # Staff login + seat-by-code + queue view — routes already defined in
  # documents/05-specifications/api-spec.md. POST /staff/seat and GET
  # /staff/queue both require the staff session token the login endpoint
  # issues (Staff::BaseController).
  namespace :staff do
    post "login" => "login#create"
    post "seat" => "seat#create"
    get "queue" => "queue#index"
  end

  # Defines the root path route ("/")
  # root "posts#index"
end

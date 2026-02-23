Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions:      "users/sessions",
    passwords:     "users/passwords",
    registrations: "users/registrations",
    confirmations: "users/confirmations",
    unlocks:       "users/unlocks"
  }

  devise_scope :user do
    get "users/check_email", to: "users/registrations#check_email", as: :check_email_users_registrations
  end

  get "dashboard", to: "dashboard#index", as: :dashboard

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  mount MissionControl::Jobs::Engine, at: "/jobs"
end

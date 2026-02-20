Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  get "dashboard", to: "dashboard#index", as: :dashboard

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"
end

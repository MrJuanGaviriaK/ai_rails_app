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

  namespace :admin do
    resources :tenants, except: :show
    resources :purchasing_locations
    resources :integrations, only: :index
    resources :e_signature_templates, except: :show do
      get :builder, on: :member
      get :builder_saved, on: :member
    end
    resources :users, only: %i[index new create destroy] do
      patch :restore, on: :member
    end
    post "tenant_context/switch", to: "tenant_contexts#switch", as: :switch_tenant_context
  end

  namespace :api do
    namespace :v1 do
      resources :integrations, only: %i[index create update destroy] do
        post :test_connection, on: :member
      end

      resources :e_signature_templates, only: %i[index create update destroy] do
        post :sync, on: :collection
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  mount MissionControl::Jobs::Engine, at: "/jobs"
end

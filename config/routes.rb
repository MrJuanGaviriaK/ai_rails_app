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
    resources :mineral_purchases, only: %i[index show new create] do
      post :retry_signature, on: :member
      get :start_signature, on: :member
      post :complete_signature, on: :member
    end
    post "mineral_purchase_direct_uploads", to: "mineral_purchase_direct_uploads#create"
    resources :integrations, only: :index
    resources :e_signature_templates, except: :show do
      get :builder, on: :member
      get :builder_saved, on: :member
    end
    resources :users, only: %i[index new create destroy] do
      patch :restore, on: :member
    end
    resources :sellers, only: %i[index show new create] do
      post :start, to: "seller_consents#start", on: :member
      post :complete, to: "seller_consents#complete", on: :member
      post :approve, to: "seller_compliance_decisions#approve", on: :member
      post :reject, to: "seller_compliance_decisions#reject", on: :member
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

  namespace :webhooks do
    post :dropbox_sign, to: "dropbox_sign#receive"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  mount MissionControl::Jobs::Engine, at: "/jobs"
end

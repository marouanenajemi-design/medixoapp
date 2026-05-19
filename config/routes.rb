Rails.application.routes.draw do
  namespace :admin do
    root "dashboard#index"

    get    "sign_in",  to: "sessions#new",     as: :sign_in
    post   "sign_in",  to: "sessions#create"
    delete "sign_out", to: "sessions#destroy", as: :sign_out

    resources :users, only: [:index, :show, :destroy] do
      member do
        patch :toggle_super_admin
      end
    end

    resources :clinics, only: [:index, :show, :destroy] do
      member do
        patch :toggle_subscription
        patch :extend_trial
        patch :update_plan
      end
    end

    resources :doctors, only: [:index, :show]
    resources :patients, only: [:index, :show]
    resources :appointments, only: [:index, :show]
  end

  get "calendar", to: "appointments#calendar"
  devise_for :users

  root "dashboard#index"

  get "dashboard", to: "dashboard#index"

  get "chatbot", to: "chatbot#index"
  post "chatbot", to: "chatbot#index"
  get "chatbot/widget", to: "chatbot#widget", as: :chatbot_widget

  get "pricing",   to: "pages#pricing"
  get "analytics", to: "analytics#index", as: :analytics
  post "/webhooks/lemonsqueezy", to: "webhooks#lemonsqueezy"

  resource :clinic, only: [:new, :create, :edit, :update]

  resources :doctors

  resources :patients do
    member do
      get :history
    end
  end

  resources :appointments

  resources :prescriptions do
    member do
      get :print
    end
  end
end

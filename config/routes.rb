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

    get   "monetization", to: "monetization#show",   as: :monetization
    patch "monetization", to: "monetization#update"

    resources :clinics, only: [:index, :show, :destroy] do
      member do
        patch :toggle_subscription
        patch :extend_trial
        patch :update_plan
        patch :update_visit_price
      end
    end

    resources :doctors,      only: [:index, :show]
    resources :patients,     only: [:index, :show]
    resources :appointments, only: [:index, :show]
  end

  # Public online booking (no auth)
  get  "/book/:slug",              to: "bookings#show",         as: :clinic_booking
  post "/book/:slug",              to: "bookings#create"
  get  "/book/:slug/slots",        to: "bookings#slots",         as: :clinic_booking_slots
  get  "/book/:slug/confirmation", to: "bookings#confirmation",  as: :clinic_booking_confirmation

  get "calendar", to: "appointments#calendar"
  devise_for :users

  # Authenticated users → dashboard; public → landing page
  authenticated :user do
    root to: "dashboard#index", as: :authenticated_root
  end
  root to: "pages#home"
  get "home", to: "pages#home", as: :landing

  get "dashboard",  to: "dashboard#index"
  get    "chatbot",            to: "chatbot#index",      as: :chatbot
  post   "chatbot/ask",        to: "chatbot#ask",        as: :chatbot_ask
  post   "chatbot/new",        to: "chatbot#new_chat",   as: :chatbot_new
  delete "chatbot/clear",      to: "chatbot#clear",      as: :chatbot_clear
  get    "chatbot/widget",     to: "chatbot#widget",     as: :chatbot_widget
  post   "chatbot/widget/ask", to: "chatbot#widget_ask", as: :chatbot_widget_ask

  get "pricing",    to: "pages#pricing"
  get "analytics",  to: "analytics#index", as: :analytics
  get "billing",    to: "billing#show",    as: :billing
  post "/webhooks/lemonsqueezy", to: "webhooks#lemonsqueezy"

  resource :clinic, only: [:new, :create, :edit, :update]

  resources :doctors

  resources :patients do
    member do
      get :history
    end
  end

  resources :appointments do
    member do
      patch :approve
      patch :reject
      patch :complete
    end
  end

  resources :prescriptions do
    member do
      get :print
    end
  end
end

Rails.application.routes.draw do
  # Authentication
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  # Dashboard
  root "dashboard#index"

  # Gyms & Machines
  resources :gyms do
    member do
      post :set_default
    end
    resources :machines
  end

  # Exercise Library
  resources :exercises do
    member do
      get :history
    end
  end

  # Workouts
  resources :workouts do
    member do
      patch :finish
      get :add_exercise
      post :add_exercise
      post :copy
      patch :reorder_blocks
    end
    resources :workout_exercises, only: [ :show, :edit, :update, :destroy ] do
      resources :exercise_sets, only: [ :create, :edit, :update, :destroy ]
      member do
        patch :move_to_block
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end

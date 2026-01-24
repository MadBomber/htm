# frozen_string_literal: true

Rails.application.routes.draw do
  # Landing page
  root 'home#index'

  # Chatbot section
  scope '/app' do
    get '/', to: 'chats#index', as: :app_root
    resources :chats, only: [:index, :show, :create, :update, :destroy] do
      resources :messages, only: [:create]
    end
    get '/models', to: 'chats#models', as: :provider_models
  end

  # HTM Management section (existing functionality)
  scope '/htm' do
    get '/', to: 'dashboard#index', as: :htm_root

    resources :memories do
      collection do
        get :deleted
      end
      member do
        post :restore
      end
    end

    resources :tags, only: [:index, :show]

    resources :robots, only: [:index, :show, :new, :create] do
      member do
        post :switch
      end
    end

    get '/search', to: 'search#index', as: :search

    resources :files, only: [:index, :show, :new, :create, :destroy] do
      collection do
        post :load_directory
        post :upload
        post :upload_directory
        post :sync_all
      end
      member do
        post :sync
      end
    end
  end
end

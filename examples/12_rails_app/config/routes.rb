# frozen_string_literal: true

Rails.application.routes.draw do
  root 'dashboard#index'

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

  resource :search, only: [:index], controller: 'search' do
    get '/', action: :index
  end

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

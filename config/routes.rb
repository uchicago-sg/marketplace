Dhaka::Application.routes.draw do
  root :to => 'listings#index', :via => :get
  post "versions/:id/revert" => "versions#revert", :as => "revert_version"
  get 'feeds' => 'categories#index'
  get 'dashboard' => 'users#dashboard'

  STATIC_PAGES.each do |page|
    match page => 'high_voltage/pages#show', :id => page
  end

  devise_for :users
  devise_scope :user do
    get "register" => "devise/registrations#new", :as => 'register'
    get "login"    => "devise/sessions#new"
    get "logout"   => "devise/sessions#destroy"
  end

  resource :starred, :controller => 'comparisons', :only => %w( create show update )

  resources :users,      :only => %w( show edit update )
  resources :categories, :path => 'browse'
  resources :listings,   :path => '' do
    collection do
      match ':id/renew'     => 'listings#renew',     :as => :renew
      get   ':id/publish'   => 'listings#publish',   :as => :publish
      get   ':id/unpublish' => 'listings#unpublish', :as => :unpublish
      match 'search' => 'listings#search', :via => [:get, :post], :as => :search
    end
  end
end
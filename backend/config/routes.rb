Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # POST /auth/:provider (start sign-in) is handled by the OmniAuth middleware.
  match "auth/:provider/callback", to: "auth#callback", via: %i[get post]
  get "auth/failure", to: "auth#failure"

  namespace :api do
    resource :session, only: %i[show destroy]
    resource :signup, only: :create
    get "nicknames/check", to: "nicknames#check"

    resources :posts, only: %i[create show]
    get "users/:nickname/posts", to: "user_posts#index", as: :user_posts
    get "places/search", to: "places#search"
    get "places/reverse", to: "places#reverse"
  end
end

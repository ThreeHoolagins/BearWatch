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
    get "feed/global", to: "feeds#global"
    get "feed/following", to: "feeds#following"

    scope "users/:nickname", constraints: { nickname: /[A-Za-z0-9_]+/ } do
      get "/", to: "users#show", as: :user
      get "posts", to: "user_posts#index", as: :user_posts
      post "follow", to: "users#follow"
      delete "follow", to: "users#unfollow"
    end
    put "me/avatar", to: "avatars#update"
    get "champion", to: "champions#show"

    namespace :admin do
      get "users", to: "users#index"
      post "users/:nickname/ban", to: "users#ban", constraints: { nickname: /[A-Za-z0-9_]+/ }
      delete "users/:nickname/ban", to: "users#unban", constraints: { nickname: /[A-Za-z0-9_]+/ }
      resources :wins, only: %i[index create destroy]
      resources :posts, only: %i[index destroy]
      get "champion", to: "champions#show"
      put "champion/:year", to: "champions#update"
    end
    get "places/search", to: "places#search"
    get "places/reverse", to: "places#reverse"
  end
end

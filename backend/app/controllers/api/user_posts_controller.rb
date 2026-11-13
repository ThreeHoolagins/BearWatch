module Api
  # Published posts for a profile's three-wide grid.
  class UserPostsController < ApplicationController
    before_action :authenticate!

    def index
      user = User.find_by(nickname: params[:nickname])
      return head :not_found unless user && (!user.banned? || user == current_user)

      posts = user.posts.published.recent.includes(:user).limit(60)
      render json: { posts: }
    end
  end
end

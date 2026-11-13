module Api
  # Published posts for a profile's three-wide grid.
  class UserPostsController < ApplicationController
    before_action :authenticate!

    def index
      user = User.find_by(nickname: params[:nickname])
      return head :not_found unless user && (!user.banned? || user == current_user)

      posts = user.posts.published.includes(user: :avatar_post).page(before: params[:before], limit: 30).to_a
      render json: { posts:, next_before: posts.size == 30 ? posts.last.id : nil }
    end
  end
end

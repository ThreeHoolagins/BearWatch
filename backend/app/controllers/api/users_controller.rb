module Api
  # Profiles: header info plus follow/unfollow.
  class UsersController < ApplicationController
    before_action :authenticate!
    before_action :set_user

    def show
      render json: {
        user: @user.public_json.merge(
          followers_count: @user.follower_links.count,
          following_count: @user.following_links.count,
          fat_bear_wins: FatBearWin.joins(:post).where(posts: { user_id: @user.id }).count,
          posts_count: @user.posts.published.count,
          me: @user == current_user,
          following: current_user.following_links.exists?(followee: @user)
        )
      }
    end

    def follow
      return render json: { error: "cant_follow_self" }, status: :unprocessable_entity if @user == current_user

      current_user.following_links.find_or_create_by!(followee: @user)
      render json: { following: true, followers_count: @user.follower_links.count }
    rescue ActiveRecord::RecordNotUnique
      render json: { following: true, followers_count: @user.follower_links.count }
    end

    def unfollow
      current_user.following_links.where(followee: @user).delete_all
      render json: { following: false, followers_count: @user.follower_links.count }
    end

    private
      # Banned users disappear for everyone else.
      def set_user
        @user = User.find_by(nickname: params[:nickname])
        head :not_found unless @user && (!@user.banned? || @user == current_user)
      end
  end
end

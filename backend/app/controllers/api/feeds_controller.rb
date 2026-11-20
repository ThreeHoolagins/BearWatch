module Api
  class FeedsController < ApplicationController
    before_action :authenticate!

    # Bears from anywhere that have been up at least 10 minutes, with ones
    # near you lifted. Location is optional; the browser sends it rounded to
    # one decimal (~11 km), and it's used for this query only and not stored.
    def global
      latitude, longitude = params[:lat], params[:lng]
      if latitude.present? || longitude.present?
        latitude = Float(latitude, exception: false)
        longitude = Float(longitude, exception: false)
        unless latitude&.between?(-90, 90) && longitude&.between?(-180, 180)
          return render json: { error: "bad_location" }, status: :unprocessable_entity
        end
        latitude, longitude = latitude.round(1), longitude.round(1)
      end

      posts = Post.visible.global_page(latitude:, longitude:, before: params[:before])
        .includes(:fat_bear_win, user: :avatar_post).to_a
      render json: { posts:, next_before: posts.size == 20 ? posts.last.feed_cursor : nil }
    end

    # Newest bears from people you follow.
    def following
      posts = Post.visible.where(user_id: current_user.following_links.select(:followee_id))
        .includes(:fat_bear_win, user: :avatar_post).page(before: params[:before]).to_a
      render json: { posts:, next_before: posts.size == 20 ? posts.last.id : nil }
    end
  end
end

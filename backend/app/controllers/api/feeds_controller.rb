module Api
  class FeedsController < ApplicationController
    RADIUS_MILES = 500

    before_action :authenticate!

    # Newest bears within 500 miles. The browser sends its location rounded
    # to one decimal (~11 km); it's used for this query only and not stored.
    def global
      latitude = Float(params[:lat], exception: false)
      longitude = Float(params[:lng], exception: false)
      unless latitude&.between?(-90, 90) && longitude&.between?(-180, 180)
        return render json: { error: "location_required" }, status: :unprocessable_entity
      end

      render_page Post.visible.near(latitude.round(1), longitude.round(1), miles: RADIUS_MILES)
    end

    # Newest bears from people you follow.
    def following
      render_page Post.visible.where(user_id: current_user.following_links.select(:followee_id))
    end

    private
      def render_page(scope)
        posts = scope.includes(user: :avatar_post).page(before: params[:before]).to_a
        render json: { posts:, next_before: posts.size == 20 ? posts.last.id : nil }
      end
  end
end

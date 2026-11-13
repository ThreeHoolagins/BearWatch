module Api
  # "Change bear face": crop one of your own photos, or go back to the blank bear.
  class AvatarsController < ApplicationController
    before_action :authenticate!

    def update
      if params[:post_id].blank?
        current_user.update!(avatar_post: nil, avatar_zoom: nil, avatar_x: nil, avatar_y: nil)
        return render json: { user: current_user }
      end

      post = current_user.posts.published.find_by(id: params[:post_id])
      return render json: { error: "not_your_photo" }, status: :unprocessable_entity unless post

      current_user.update!(
        avatar_post: post,
        avatar_zoom: number(:zoom, 1.0, 4.0, default: 1.0),
        avatar_x: number(:x, 0.0, 1.0, default: 0.5),
        avatar_y: number(:y, 0.0, 1.0, default: 0.5)
      )
      render json: { user: current_user }
    end

    private
      def number(key, min, max, default:)
        Float(params[key], exception: false)&.clamp(min, max) || default
      end
  end
end

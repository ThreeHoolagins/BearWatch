module Api
  class PostsController < ApplicationController
    PER_MINUTE = 1
    PER_DAY = 20

    before_action :authenticate!
    # Attempts (including rejected photos) per minute, on top of the
    # one-accepted-bear-per-minute rule below.
    rate_limit to: 5, within: 1.minute, by: -> { current_user.id }, only: :create

    def create
      upload = PhotoUpload.new(params[:photo])
      return render_error(upload.errors.full_messages.first, :unprocessable_entity) unless upload.valid?

      latitude = Float(params[:latitude], exception: false)
      longitude = Float(params[:longitude], exception: false)
      return render_error("Pick where you saw this bear.", :unprocessable_entity) unless latitude && longitude

      if (wait = seconds_until_next_upload)
        return render json: { error: "slow_down", message: slow_down_message(wait), retry_after: wait }, status: :too_many_requests
      end

      post = current_user.posts.new(place_name: params[:place_name].to_s, latitude:, longitude:)
      return render_error(post.errors.full_messages.first, :unprocessable_entity) unless post.save

      begin
        FileUtils.cp(upload.file.tempfile.path, post.raw_path)
      rescue SystemCallError
        post.destroy
        raise
      end
      ProcessPhotoJob.perform_later(post.id)
      render json: { post: }, status: :accepted
    end

    # Used by the post form to poll while the worker checks for a bear.
    def show
      post = Post.find_by(id: params[:id])
      return head :not_found unless post && (post.published? || post.user_id == current_user.id)

      render json: { post: }
    end

    private
      def render_error(message, status)
        render json: { error: "invalid", message: }, status:
      end

      # Rejected and failed photos don't count against the limits.
      def seconds_until_next_upload
        counted = current_user.posts.where(status: %w[processing published])
        if counted.where(created_at: 1.day.ago..).count >= PER_DAY
          oldest = counted.where(created_at: 1.day.ago..).minimum(:created_at)
          return (oldest + 1.day - Time.current).ceil.clamp(1, 1.day.to_i)
        end
        last = counted.where(created_at: 1.minute.ago..).maximum(:created_at)
        (last + 1.minute - Time.current).ceil.clamp(1, 60) if last
      end

      def slow_down_message(wait)
        if wait > 60
          "That's #{PER_DAY} bears today! Come back tomorrow for more."
        else
          "One bear a minute, please. Try again in #{wait} second#{"s" unless wait == 1}."
        end
      end
  end
end

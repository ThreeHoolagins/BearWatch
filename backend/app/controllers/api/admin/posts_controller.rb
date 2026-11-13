module Api
  module Admin
    class PostsController < BaseController
      # Recent published posts, for picking the champion card's photo.
      def index
        posts = Post.visible.includes(:fat_bear_win, user: :avatar_post).recent.limit(60)
        render json: { posts: }
      end

      # Take down a post that breaks the rules (also deletes the photo).
      def destroy
        Post.find(params[:id]).destroy!
        head :no_content
      end
    end
  end
end

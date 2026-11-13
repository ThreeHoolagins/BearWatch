module Api
  module Admin
    # Fat Bear Week wins, awarded by hand to the post matching the real winner.
    class WinsController < BaseController
      def index
        wins = FatBearWin.includes(post: [ :fat_bear_win, { user: :avatar_post } ]).order(year: :desc)
        render json: { wins: }
      end

      def create
        post = Post.find_by(id: params[:post_id])
        win = FatBearWin.new(post:, year: params[:year], awarded_by: current_user)
        return render_errors(win) unless win.save

        render json: { win: }, status: :created
      end

      def destroy
        FatBearWin.find(params[:id]).destroy!
        head :no_content
      end
    end
  end
end

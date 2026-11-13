module Api
  module Admin
    # Search users, ban (with the reason they'll see), unban.
    class UsersController < BaseController
      PER_PAGE = 50

      def index
        users = User.includes(:avatar_post).order(Arel.sql("banned_at IS NULL"), created_at: :desc)
        query = params[:q].to_s.strip
        users = users.where("nickname LIKE ?", "%#{User.sanitize_sql_like(query)}%") if query.present?
        users = users.where.not(banned_at: nil) if params[:banned] == "1"
        render json: { users: users.limit(PER_PAGE).map(&:admin_json) }
      end

      def ban
        user = User.find_by!(nickname: params[:nickname])
        reason = params[:reason].to_s.squish
        return render json: { error: "invalid", message: "Give a reason. The user will see it." }, status: :unprocessable_entity if reason.blank?
        return render json: { error: "invalid", message: "Keep the reason under 500 characters." }, status: :unprocessable_entity if reason.length > 500
        return render json: { error: "invalid", message: "You can't ban yourself." }, status: :unprocessable_entity if user == current_user
        return render json: { error: "invalid", message: "Admins can't be banned here. Remove their admin rights first." }, status: :unprocessable_entity if user.is_admin?

        user.ban!(reason)
        render json: { user: user.admin_json }
      end

      def unban
        user = User.find_by!(nickname: params[:nickname])
        user.unban!
        render json: { user: user.admin_json }
      end
    end
  end
end

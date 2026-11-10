class ApplicationController < ActionController::API
  # The SPA sends the token from GET /api/session in an X-CSRF-Token header.
  include ActionController::RequestForgeryProtection
  protect_from_forgery with: :exception

  rescue_from ActionController::InvalidAuthenticityToken do
    render json: { error: "invalid_csrf" }, status: :unprocessable_entity
  end

  private
    def current_user
      return @current_user if defined?(@current_user)
      @current_user = session[:user_id] && User.find_by(id: session[:user_id])
    end

    def sign_in(user)
      reset_session
      session[:user_id] = user.id
      @current_user = user
    end

    # Signed in and not banned. Banned users can only read their session
    # (to see the ban reason) and sign out.
    def authenticate!
      if current_user.nil?
        render json: { error: "signed_out" }, status: :unauthorized
      elsif current_user.banned?
        render json: { error: "banned", reason: current_user.ban_reason }, status: :forbidden
      end
    end

    def require_admin!
      authenticate!
      render json: { error: "forbidden" }, status: :forbidden unless performed? || current_user.is_admin?
    end

    # Set after an SSO callback for an account we haven't seen, until the
    # person picks a nickname.
    def pending_identity
      pending = session[:pending_identity]
      pending if pending.is_a?(Hash) && pending["expires_at"].to_i > Time.current.to_i
    end
end

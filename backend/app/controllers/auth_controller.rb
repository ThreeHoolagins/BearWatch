# OmniAuth callbacks. The request phase (POST /auth/:provider) is handled by
# the OmniAuth middleware; see config/initializers/omniauth.rb.
class AuthController < ApplicationController
  # Providers come back with a GET (Google/GitHub) or a POST (developer form)
  # and no CSRF token; OmniAuth's state parameter protects this step.
  skip_forgery_protection only: %i[callback failure]

  PENDING_SIGNUP_TTL = 30.minutes

  def callback
    auth = request.env["omniauth.auth"]
    provider, uid = auth.provider.to_s, auth.uid.to_s
    identity = Identity.find_by(provider:, uid:)

    if current_user
      link_identity(identity, provider, uid)
    elsif identity
      sign_in(identity.user)
      redirect_to "/"
    else
      reset_session
      session[:pending_identity] = { "provider" => provider, "uid" => uid, "expires_at" => PENDING_SIGNUP_TTL.from_now.to_i }
      redirect_to "/welcome"
    end
  end

  def failure
    redirect_to "/?auth_error=#{CGI.escape(params[:message].to_s)}"
  end

  private
    def link_identity(identity, provider, uid)
      if identity.nil?
        current_user.identities.create!(provider:, uid:)
        redirect_to "/profile?linked=#{provider}"
      elsif identity.user_id == current_user.id
        redirect_to "/profile"
      else
        redirect_to "/profile?link_error=taken"
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to "/profile?link_error=already_linked"
    end
end

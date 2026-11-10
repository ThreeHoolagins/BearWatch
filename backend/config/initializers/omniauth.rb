# SSO sign-in. We request the smallest scopes possible and keep only the
# provider's stable account id (see AuthController).
Rails.application.config.middleware.use OmniAuth::Builder do
  # Development only: sign in as any made-up account without real OAuth apps.
  provider :developer, fields: [ :name ], uid_field: :name if OmniauthProviders.developer?

  google_id, google_secret = OmniauthProviders.google
  provider :google_oauth2, google_id, google_secret, scope: "openid", prompt: "select_account" if google_id

  github_id, github_secret = OmniauthProviders.github
  provider :github, github_id, github_secret, scope: "" if github_id
end

# Starting sign-in must be a POST carrying the CSRF token
# (omniauth-rails_csrf_protection checks it).
OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.logger = Rails.logger
OmniAuth.config.on_failure = proc { |env| OmniAuth::FailureEndpoint.new(env).redirect_to_failure }

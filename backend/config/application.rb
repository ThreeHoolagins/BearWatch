require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "../lib/middleware/error_alerts"

module Bearwatch
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks middleware])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # API-only apps drop cookies and sessions; we add them back because sign-in
    # uses an HttpOnly session cookie (the SPA is served from the same origin).
    config.session_store :cookie_store, key: "_bearwatch_session", same_site: :lax,
      secure: Rails.env.production?, httponly: true, expire_after: 30.days
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options

    # Background jobs (photo processing) run in the worker container via Solid
    # Queue, using the main database.
    config.active_job.queue_adapter = :solid_queue
    # Queues: "photos" runs in the offline worker; "online" (R2 uploads, Discord alerts,
    # usage checks) runs inside the web process, which has internet access.

    # Discord alert when we start answering with 429s or 5xx errors.
    config.middleware.insert(0, ErrorAlerts)

    # Rate limiting (ActionController::RateLimiting) needs a real cache store.
    config.cache_store = :memory_store
  end
end

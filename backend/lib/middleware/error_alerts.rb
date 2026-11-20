# Pings the ranger on Discord when Bear Watch starts answering with 429s
# (rate limits) or 5xx errors. Sits outside everything else so it sees the
# status the browser actually gets. Each status code alerts at most once per
# MUTE_FOR, so a burst of errors is one message, not hundreds.
class ErrorAlerts
  MUTE_FOR = 10.minutes

  # Set by a controller that has already sent its own alert for this response
  # (e.g. out of honey), so it isn't reported twice.
  ALREADY_ALERTED = "bearwatch.already_alerted".freeze

  def initialize(app)
    @app = app
    @muted = ActiveSupport::Cache::MemoryStore.new
  end

  def call(env)
    status, headers, body = @app.call(env)
    alert(env, status) if (status == 429 || status >= 500) && !env[ALREADY_ALERTED]
    [ status, headers, body ]
  rescue Exception => error # rubocop:disable Lint/RescueException
    alert(env, 500, error)
    raise
  end

  private
    def alert(env, status, error = env["action_dispatch.exception"])
      return unless DiscordAlertJob.enabled?
      return unless @muted.write(status, true, unless_exist: true, expires_in: MUTE_FOR)

      message = message(ActionDispatch::Request.new(env), status, error)
      begin
        DiscordAlertJob.perform_later(message)
      rescue StandardError
        # Probably the database (and so the job queue) is what's broken: send directly.
        Thread.new { DiscordAlertJob.perform_now(message) rescue nil }
      end
    rescue StandardError => alert_error
      Rails.logger.error("[alerts] Couldn't send the #{status} alert: #{alert_error.class}: #{alert_error.message}")
    end

    def message(request, status, error)
      site = ENV["APP_HOST"].presence || "localhost"
      reason = Rack::Utils::HTTP_STATUS_CODES[status]
      headline = status == 429 ? "Bear Watch is rate limiting requests" : "Bear Watch is returning #{status}s"
      lines = [ ":rotating_light: **#{headline}** (#{site})", "`#{request.request_method} #{request.path}` -> #{status} #{reason}" ]
      lines << "Error: `#{"#{error.class}: #{error.message}".squish.first(300)}`" if error
      lines << "Further #{status}s are muted for #{MUTE_FOR.inspect}. Logs: `docker compose logs web`"
      lines.join("\n")
    end
end

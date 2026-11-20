require "test_helper"

class ErrorAlertsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup { ENV["DISCORD_WEBHOOK_URL"] = "https://discord.com/api/webhooks/1/test" }
  teardown { ENV.delete("DISCORD_WEBHOOK_URL") }

  def middleware(status: 200, error: nil, env_flags: {})
    ErrorAlerts.new(lambda do |env|
      env.merge!(env_flags)
      raise error if error
      [ status, {}, [ "" ] ]
    end)
  end

  def call(app, path = "/api/feeds")
    app.call(Rack::MockRequest.env_for(path))
  end

  def alerts
    enqueued_jobs.select { _1["job_class"] == "DiscordAlertJob" }.map { _1["arguments"].first }
  end

  test "ignores normal responses and client errors" do
    [ 200, 404, 422 ].each { call(middleware(status: _1)) }
    assert_empty alerts
  end

  test "alerts on a 500 with the request, once per mute window" do
    app = middleware(status: 500)
    3.times { call(app) }

    assert_equal 1, alerts.size
    assert_match "returning 500s", alerts.first
    assert_match "`GET /api/feeds` -> 500 Internal Server Error", alerts.first

    travel ErrorAlerts::MUTE_FOR + 1.minute do
      call(app)
    end
    assert_equal 2, alerts.size
  end

  test "alerts on 429s, separately from 5xx" do
    call(middleware(status: 429))
    assert_match "rate limiting", alerts.last
    call(middleware(status: 503))
    assert_equal 2, alerts.size
  end

  test "alerts on an exception that escapes the app, then re-raises it" do
    app = middleware(error: NoMethodError.new("undefined method 'growl'"))
    assert_raises(NoMethodError) { call(app) }
    assert_match "NoMethodError: undefined method 'growl'", alerts.first
  end

  test "skips responses a controller already alerted about" do
    call(middleware(status: 503, env_flags: { ErrorAlerts::ALREADY_ALERTED => true }))
    assert_empty alerts
  end

  test "does nothing without a webhook" do
    ENV.delete("DISCORD_WEBHOOK_URL")
    call(middleware(status: 500))
    assert_empty alerts
  end
end

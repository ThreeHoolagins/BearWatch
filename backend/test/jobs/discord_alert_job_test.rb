require "test_helper"

class DiscordAlertJobTest < ActiveJob::TestCase
  Response = Struct.new(:code, :body)

  setup { ENV["DISCORD_WEBHOOK_URL"] = "https://discord.com/api/webhooks/1/test" }
  teardown { ENV.delete("DISCORD_WEBHOOK_URL") }

  def post_returning(response_class, code)
    sent = []
    original = Net::HTTP.method(:post)
    Net::HTTP.define_singleton_method(:post) do |uri, body, _headers|
      sent << [ uri.to_s, JSON.parse(body) ]
      response_class.new("1.1", code, "").tap { _1.instance_variable_set(:@read, true) }
    end
    yield
    sent
  ensure
    Net::HTTP.define_singleton_method(:post, original)
  end

  test "posts the message to the webhook with an @here ping" do
    sent = post_returning(Net::HTTPNoContent, "204") { DiscordAlertJob.perform_now("Out of honey") }

    assert_equal 1, sent.size
    url, payload = sent.first
    assert_equal "https://discord.com/api/webhooks/1/test", url
    assert_equal "@here Out of honey", payload["content"]
    assert_equal({ "parse" => [ "everyone" ] }, payload["allowed_mentions"])
  end

  test "trims messages to Discord's limit" do
    sent = post_returning(Net::HTTPNoContent, "204") { DiscordAlertJob.perform_now("a" * 3000) }
    assert_equal DiscordAlertJob::MAX_LENGTH, sent.first.last["content"].length
  end

  test "retries when Discord is rate limiting" do
    post_returning(Net::HTTPTooManyRequests, "429") do
      assert_enqueued_jobs(1, only: DiscordAlertJob) { DiscordAlertJob.perform_now("hi") }
    end
  end

  test "does nothing without a webhook" do
    ENV.delete("DISCORD_WEBHOOK_URL")
    assert_empty post_returning(Net::HTTPNoContent, "204") { DiscordAlertJob.perform_now("hi") }
  end
end

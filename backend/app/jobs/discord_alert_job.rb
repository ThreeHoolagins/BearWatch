require "net/http"

# Posts a message to the ranger's Discord channel through DISCORD_WEBHOOK_URL,
# with @here so it notifies whoever is online.
# Runs on the "online" queue (the web process has internet access).
class DiscordAlertJob < ApplicationJob
  queue_as :online

  # Discord is down or rate limiting us: try again for about 10 minutes.
  class Unavailable < StandardError; end

  retry_on Unavailable, SystemCallError, IOError, Timeout::Error, SocketError, wait: 1.minute, attempts: 10

  # Discord rejects messages longer than this.
  MAX_LENGTH = 2000

  def self.enabled?
    ENV["DISCORD_WEBHOOK_URL"].present?
  end

  def perform(content)
    url = ENV["DISCORD_WEBHOOK_URL"].presence or return
    body = { content: "@here #{content}".truncate(MAX_LENGTH), allowed_mentions: { parse: [ "everyone" ] } }.to_json
    response = Net::HTTP.post(URI(url), body, "Content-Type" => "application/json")

    case response
    when Net::HTTPSuccess
      nil
    when Net::HTTPTooManyRequests, Net::HTTPServerError
      raise Unavailable, "Discord returned #{response.code}"
    else
      # A bad or deleted webhook won't fix itself; don't retry.
      Rails.logger.error("[discord] Webhook rejected the alert (#{response.code}): #{response.body.to_s.first(200)}")
    end
  end
end

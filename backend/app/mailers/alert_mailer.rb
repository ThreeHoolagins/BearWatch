class AlertMailer < ApplicationMailer
  # Retried by Solid Queue if the SMTP server is briefly unreachable.
  def out_of_honey(recipient:, trigger:, usage_summary:)
    @trigger = trigger
    @usage_summary = usage_summary
    @site = ENV["APP_HOST"].presence || "localhost"
    mail(to: recipient, subject: "Bear Watch is out of honey: photo uploads are paused")
  end
end

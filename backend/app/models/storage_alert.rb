# Emails the owner the first time in a month that storage runs out.
module StorageAlert
  def self.out_of_honey!(trigger)
    recipient = ENV["ALERT_EMAIL"].presence
    unless recipient
      Rails.logger.error("[storage] Out of honey (#{trigger}) but ALERT_EMAIL isn't set; no email sent.")
      return
    end

    month = StorageMonth.current
    # Only the request that flips alerted_at from nil sends the email.
    claimed = StorageMonth.where(id: month.id, alerted_at: nil).update_all(alerted_at: Time.current) == 1
    return unless claimed

    Rails.logger.warn("[storage] Out of honey (#{trigger}); emailing #{recipient}.")
    AlertMailer.out_of_honey(recipient:, trigger:, usage_summary: StorageQuota.usage.summary).deliver_later
  end
end

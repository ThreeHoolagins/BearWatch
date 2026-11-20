# Tells the ranger on Discord the first time in a month that storage runs out.
module StorageAlert
  def self.out_of_honey!(trigger)
    unless DiscordAlertJob.enabled?
      Rails.logger.error("[storage] Out of honey (#{trigger}) but DISCORD_WEBHOOK_URL isn't set; no alert sent.")
      return
    end

    month = StorageMonth.current
    # Only the request that flips alerted_at from nil sends the alert.
    claimed = StorageMonth.where(id: month.id, alerted_at: nil).update_all(alerted_at: Time.current) == 1
    return unless claimed

    Rails.logger.warn("[storage] Out of honey (#{trigger}); alerting Discord.")
    DiscordAlertJob.perform_later(message(trigger, StorageQuota.usage.summary))
  end

  def self.message(trigger, usage_summary)
    site = ENV["APP_HOST"].presence || "localhost"
    <<~MESSAGE
      :honey_pot: **Bear Watch is out of honey: photo uploads are paused** (#{site})

      Bear Watch has reached its Cloudflare R2 free-tier cap. Bear watchers now see:
      > #{StorageQuota::OUT_OF_HONEY}

      **What triggered it:** #{trigger}

      **Current usage:**
      ```
      #{usage_summary}
      ```
      Nothing will be charged: Bear Watch stops before going past the free tier.

      **To get uploads going again**, do one of:
      - wait for next month (write/read limits reset on the 1st; storage doesn't),
      - delete old photos, or
      - raise `R2_STORAGE_LIMIT_GB` / `R2_CLASS_A_LIMIT` / `R2_CLASS_B_LIMIT` in `.env` (anything over the free tier is billed by Cloudflare) and restart.

      Check usage any time with `docker compose exec web bin/rails bearwatch:storage:status`.
      You'll get at most one of these alerts per month.
    MESSAGE
  end
end

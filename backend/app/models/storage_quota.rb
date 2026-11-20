# Keeps Bear Watch inside Cloudflare R2's free tier. Once any limit would be
# crossed, uploads stop with "Oops! Ran out of honey" and the ranger gets a Discord
# alert (once per month, see StorageAlert).
#
# Free tier: 10 GB-month storage, 1M Class A ops (writes/lists), 10M Class B
# ops (reads) per month. Defaults stop a little short of each, for headroom.
#
# Storage and writes are counted by us: Bear Watch is the only thing writing
# to the bucket. Reads happen directly between browsers and Cloudflare, so
# they're only counted if R2_ANALYTICS_TOKEN can read Cloudflare's analytics.
module StorageQuota
  OUT_OF_HONEY = "Oops! Ran out of honey. A ranger needs to fix this.".freeze
  GB = 1024**3

  # Room to leave for a photo we haven't processed yet (WebPs are capped at
  # 2048px, typically 200-600 KB).
  EXPECTED_PHOTO_BYTES = 2 * 1024 * 1024

  Usage = Data.define(:bytes, :bytes_limit, :class_a, :class_a_limit, :class_b, :class_b_limit) do
    def over?(extra_bytes = 0)
      bytes + extra_bytes > bytes_limit || class_a + 1 > class_a_limit || (class_b.to_i > class_b_limit)
    end

    def summary
      [
        "Storage: #{ActiveSupport::NumberHelper.number_to_human_size(bytes)} of #{ActiveSupport::NumberHelper.number_to_human_size(bytes_limit)}",
        "Writes this month (Class A): #{class_a} of #{class_a_limit}",
        "Reads this month (Class B): #{class_b.nil? ? "not tracked (no analytics token)" : "#{class_b} of #{class_b_limit}"}"
      ].join("\n")
    end
  end

  class << self
    def enforced?
      PhotoStorage.r2?
    end

    def usage
      month = StorageMonth.current
      counted = Post.where(storage: "r2").sum(:image_bytes) + FatBearChampion.where(image_storage: "r2").sum(:image_bytes)
      Usage.new(
        bytes: [ counted, month.observed_bytes.to_i ].max,
        bytes_limit: (Float(ENV.fetch("R2_STORAGE_LIMIT_GB", "9.5")) * GB).to_i,
        class_a: month.class_a_ops,
        class_a_limit: Integer(ENV.fetch("R2_CLASS_A_LIMIT", "950000")),
        class_b: month.class_b_ops,
        class_b_limit: Integer(ENV.fetch("R2_CLASS_B_LIMIT", "9500000"))
      )
    end

    # True when storing another photo (of extra_bytes) would cross a limit.
    def exhausted?(extra_bytes = EXPECTED_PHOTO_BYTES)
      enforced? && usage.over?(extra_bytes)
    end
  end
end

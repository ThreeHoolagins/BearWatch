# R2 usage for one calendar month. Operation limits on Cloudflare's free tier
# reset monthly; storage is billed as the month's average, so staying under
# the cap at all times keeps it free.
class StorageMonth < ApplicationRecord
  def self.current
    month = Date.current.beginning_of_month
    find_or_create_by!(month:)
  rescue ActiveRecord::RecordNotUnique
    find_by!(month:)
  end

  # Atomic, so concurrent uploads can't lose a count.
  def self.record_class_a!(count = 1)
    update_counters(current.id, class_a_ops: count)
  end
end

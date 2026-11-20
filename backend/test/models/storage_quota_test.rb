require "test_helper"

class StorageQuotaTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(nickname: "grizzwald")
    @env = ENV.to_h.slice("R2_STORAGE_LIMIT_GB", "R2_CLASS_A_LIMIT", "DISCORD_WEBHOOK_URL")
    ENV["DISCORD_WEBHOOK_URL"] = "https://discord.com/api/webhooks/1/test"
  end

  teardown do
    %w[R2_STORAGE_LIMIT_GB R2_CLASS_A_LIMIT DISCORD_WEBHOOK_URL].each { ENV.delete(_1) }
    @env.each { |k, v| ENV[k] = v }
  end

  def with_r2(&block)
    stubbing(PhotoStorage, :r2?, true, &block)
  end

  def r2_post(bytes)
    @user.posts.create!(place_name: "Estes Park, CO", latitude: 40.4, longitude: -105.5, status: "published",
                        storage: "r2", image_key: SecureRandom.hex(8), image_bytes: bytes)
  end

  test "not enforced with local storage" do
    ENV["R2_STORAGE_LIMIT_GB"] = "0"
    assert_not StorageQuota.exhausted?
  end

  test "counts R2 bytes and stops before the storage limit" do
    ENV["R2_STORAGE_LIMIT_GB"] = (5.0 * 1024 * 1024 / StorageQuota::GB).to_s # 5 MB
    with_r2 do
      r2_post(2 * 1024 * 1024)
      assert_not StorageQuota.exhausted?, "2 MB used + 2 MB expected fits in 5 MB"
      r2_post(2 * 1024 * 1024)
      assert StorageQuota.exhausted?, "4 MB used + 2 MB expected doesn't"
    end
  end

  test "uses the bucket's measured size when it's bigger than our count" do
    ENV["R2_STORAGE_LIMIT_GB"] = "1"
    StorageMonth.current.update!(observed_bytes: StorageQuota::GB)
    with_r2 { assert StorageQuota.exhausted? }
  end

  test "stops before the monthly write limit" do
    ENV["R2_CLASS_A_LIMIT"] = "10"
    StorageMonth.record_class_a!(10)
    with_r2 { assert StorageQuota.exhausted?(0) }
  end

  test "alerts once per month, no matter how many uploads hit the cap" do
    assert_enqueued_jobs(1, only: DiscordAlertJob) do
      3.times { StorageAlert.out_of_honey!("test") }
    end
    assert StorageMonth.current.alerted_at

    StorageMonth.current.update!(month: 1.month.ago.beginning_of_month.to_date) # pretend it was last month
    assert_enqueued_jobs(1, only: DiscordAlertJob) { StorageAlert.out_of_honey!("new month") }
  end

  test "the alert explains what happened" do
    message = StorageAlert.message("someone uploaded", "Storage: 9.5 GB of 9.5 GB")
    assert_match "out of honey", message
    assert_match "Oops! Ran out of honey. A ranger needs to fix this.", message
    assert_match "someone uploaded", message
    assert_match "Storage: 9.5 GB of 9.5 GB", message
    assert_operator message.length, :<=, DiscordAlertJob::MAX_LENGTH
  end

  test "no Discord webhook configured: logs instead of failing" do
    ENV.delete("DISCORD_WEBHOOK_URL")
    assert_no_enqueued_jobs(only: DiscordAlertJob) { StorageAlert.out_of_honey!("test") }
    assert_nil StorageMonth.current.alerted_at
  end
end

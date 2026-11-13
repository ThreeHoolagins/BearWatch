require "net/http"

# Every few hours: measure the bucket's real size (in case anything else
# writes to it), and, if R2_ANALYTICS_TOKEN can read Cloudflare's analytics,
# this month's read/write counts. If that pushes usage over the cap, the
# owner is emailed even before anyone tries to upload.
class CheckStorageUsageJob < ApplicationJob
  queue_as :online

  # Cloudflare's billing classes (https://developers.cloudflare.com/r2/pricing/).
  CLASS_B = %w[HeadBucket HeadObject GetObject UsageSummary GetBucketEncryption GetBucketLocation
               GetBucketCors GetBucketLifecycleConfiguration].freeze
  FREE = %w[DeleteObject DeleteBucket AbortMultipartUpload].freeze

  def perform
    return unless PhotoStorage.r2?

    month = StorageMonth.current
    month.update!(observed_bytes: R2Client.new.total_bytes, observed_at: Time.current)
    if (ops = analytics_operations)
      month.update!(class_b_ops: ops[:class_b], class_a_ops: [ month.reload.class_a_ops, ops[:class_a] ].max)
    end

    StorageAlert.out_of_honey!("the scheduled usage check found the free tier used up") if StorageQuota.usage.over?(0)
  end

  private
    # Needs a Cloudflare API token with "Account Analytics: Read".
    def analytics_operations
      token = ENV["R2_ANALYTICS_TOKEN"].presence or return
      query = <<~GRAPHQL
        query($account: String!, $since: Time!, $bucket: String!) {
          viewer { accounts(filter: { accountTag: $account }) {
            r2OperationsAdaptiveGroups(limit: 1000, filter: { datetime_geq: $since, bucketName: $bucket }) {
              sum { requests } dimensions { actionType }
            }
          } }
        }
      GRAPHQL
      variables = { account: ENV.fetch("R2_ACCOUNT_ID"), bucket: ENV.fetch("R2_BUCKET"),
                    since: Time.current.utc.beginning_of_month.iso8601 }
      uri = URI("https://api.cloudflare.com/client/v4/graphql")
      response = Net::HTTP.post(uri, { query:, variables: }.to_json,
                                "Authorization" => "Bearer #{token}", "Content-Type" => "application/json")
      groups = JSON.parse(response.body).dig("data", "viewer", "accounts", 0, "r2OperationsAdaptiveGroups")
      unless groups
        Rails.logger.warn("[storage] Cloudflare analytics unavailable: #{response.body.first(200)}")
        return
      end

      totals = { class_a: 0, class_b: 0 }
      groups.each do |group|
        action, count = group.dig("dimensions", "actionType"), group.dig("sum", "requests").to_i
        next if FREE.include?(action)
        totals[CLASS_B.include?(action) ? :class_b : :class_a] += count
      end
      totals
    rescue SystemCallError, IOError, Timeout::Error, SocketError, JSON::ParserError => error
      Rails.logger.warn("[storage] Cloudflare analytics unreachable: #{error.class}")
      nil
    end
end

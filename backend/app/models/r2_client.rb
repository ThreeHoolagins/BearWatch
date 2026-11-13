require "aws-sdk-s3"

# Cloudflare R2 through its S3-compatible API. Every billable call is counted
# in StorageMonth so StorageQuota can stop before the free tier runs out.
class R2Client
  def initialize
    @bucket = ENV.fetch("R2_BUCKET")
    @s3 = Aws::S3::Client.new(
      endpoint: ENV.fetch("R2_ENDPOINT"),
      access_key_id: ENV.fetch("R2_ACCESS_KEY_ID"),
      secret_access_key: ENV.fetch("R2_SECRET_ACCESS_KEY"),
      region: "auto",
      # R2 doesn't need the newer default checksum headers.
      request_checksum_calculation: "when_required",
      response_checksum_validation: "when_required",
      retry_limit: 2,
      http_open_timeout: 5,
      http_read_timeout: 30
    )
  end

  # Class A operation.
  def put_webp(key, path)
    File.open(path, "rb") do |file|
      @s3.put_object(bucket: @bucket, key:, body: file, content_type: "image/webp",
                     cache_control: "public, max-age=31536000, immutable")
    end
    StorageMonth.record_class_a!
  end

  # Free.
  def delete(key)
    @s3.delete_object(bucket: @bucket, key:)
  end

  # Adds up every object's size. One Class A operation per 1,000 objects.
  def total_bytes
    total, calls, token = 0, 0, nil
    loop do
      page = @s3.list_objects_v2(bucket: @bucket, continuation_token: token)
      calls += 1
      total += page.contents.sum(&:size)
      break unless page.is_truncated
      token = page.next_continuation_token
    end
    StorageMonth.record_class_a!(calls)
    total
  end
end

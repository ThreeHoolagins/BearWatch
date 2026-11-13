require "aws-sdk-s3"

# Uploads a processed WebP to R2 and publishes the post. Runs in the web
# process ("online" queue) because the photo worker has no internet access.
class StorePhotoJob < ApplicationJob
  queue_as :online

  STORAGE_ERRORS = [ Aws::S3::Errors::ServiceError, Seahorse::Client::NetworkingError, Timeout::Error, SystemCallError ].freeze

  # R2 hiccup: retry for about 5 minutes, then give up on this photo.
  retry_on(*STORAGE_ERRORS, wait: 30.seconds, attempts: 10) do |job, _error|
    post = Post.find_by(id: job.arguments.first)
    if post&.processing?
      FileUtils.rm_f(PhotoStorage.media_path(post.image_key)) if post.image_key
      post.update!(status: "failed", failure_reason: "storage_unavailable")
    end
  end

  discard_on ActiveRecord::RecordNotFound

  def perform(post_id)
    post = Post.find(post_id)
    return unless post.processing? && post.image_key

    local = PhotoStorage.media_path(post.image_key)
    return post.update!(status: "failed", failure_reason: "unreadable") unless local.exist?

    if StorageQuota.exhausted?(local.size)
      FileUtils.rm_f(local)
      post.update!(status: "failed", failure_reason: "out_of_storage")
      StorageAlert.out_of_honey!("a photo by #{post.user.nickname} didn't fit in the free tier")
      return
    end

    R2Client.new.put_webp(PhotoStorage.r2_key(post.image_key), local)
    post.update!(status: "published", storage: "r2", image_bytes: local.size)
    FileUtils.rm_f(local)
  end
end

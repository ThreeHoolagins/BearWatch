class ProcessPhotoJob < ApplicationJob
  queue_as :photos

  # Detector restarting or busy: try again for about two minutes, then give up.
  retry_on BearDetectorClient::Unavailable, wait: 10.seconds, attempts: 12 do |job, _error|
    post = Post.find_by(id: job.arguments.first)
    if post&.processing?
      post.update!(status: "failed", failure_reason: "detector_unavailable")
      FileUtils.rm_f(post.raw_path)
    end
  end

  discard_on ActiveRecord::RecordNotFound

  def perform(post_id)
    post = Post.find(post_id)
    return unless post.processing?

    PhotoProcessor.new(post).call
  end
end

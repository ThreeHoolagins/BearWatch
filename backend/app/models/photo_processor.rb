# Turns an uploaded original into a published WebP, or rejects it. Runs in the
# worker container, which has no internet access.
#
#   1. Read only the image header and reject anything over 50 megapixels.
#   2. Re-encode with vipsthumbnail under a hard timeout: auto-rotate, convert
#      to sRGB, fit within 2048px, save as WebP with all metadata stripped
#      (EXIF GPS, camera details, etc). See ImageTools.
#   3. Ask the detector about the re-encoded image (never the original).
#      Reject if a person is visible (Terms of Service) or there's no bear.
#   4. Publish (local disk, or hand off to StorePhotoJob for R2) or reject,
#      and always delete the original.
class PhotoProcessor
  def initialize(post, detector: BearDetectorClient.new)
    @post = post
    @detector = detector
  end

  def call
    return finish(:rejected, "too_large") if ImageTools.too_large?(@post.raw_path)

    output = PhotoStorage.uploads_dir.join("post-#{@post.id}-#{SecureRandom.hex(6)}.webp")
    out_width, out_height = ImageTools.to_webp(@post.raw_path, output)

    verdict = @detector.detect(File.binread(output))
    @post.bear_score = verdict.bear_score
    @post.bear_x, @post.bear_y, @post.bear_w, @post.bear_h = verdict.bear_box if verdict.bear_box&.size == 4

    if verdict.person_detected
      finish(:rejected, "person")
    elsif verdict.is_bear
      publish(output, out_width, out_height)
    else
      finish(:rejected, "no_bear")
    end
  rescue ImageTools::Unreadable, BearDetectorClient::Unreadable
    finish(:failed, "unreadable")
  ensure
    # Leaves the original in place only if the detector was unavailable, so a retry can use it.
    FileUtils.rm_f(output) if output
  end

  private
    # Local storage publishes right away. With R2 the web process uploads it
    # (this worker has no internet) and publishes once it's stored.
    def publish(output, width, height)
      key = PhotoStorage.new_key
      FileUtils.mv(output, PhotoStorage.media_path(key))
      attributes = { image_key: key, width:, height:, image_bytes: PhotoStorage.media_path(key).size, failure_reason: nil }
      if PhotoStorage.r2?
        @post.update!(attributes)
        StorePhotoJob.perform_later(@post.id)
      else
        @post.update!(attributes.merge(status: "published"))
      end
      delete_original
    end

    def finish(status, reason)
      @post.update!(status:, failure_reason: reason)
      delete_original
    end

    def delete_original
      FileUtils.rm_f(@post.raw_path)
    end
end

require "open3"

# Turns an uploaded original into a published WebP, or rejects it. Runs in the
# worker container, which has no internet access.
#
#   1. Read only the image header and reject anything over MAX_PIXELS.
#   2. Re-encode with vipsthumbnail under a hard timeout: auto-rotate, convert
#      to sRGB, fit within MAX_EDGE, save as WebP with all metadata stripped
#      (EXIF GPS, camera details, etc).
#   3. Ask the detector about the re-encoded image (never the original).
#   4. Publish (move into media) or reject, and always delete the original.
class PhotoProcessor
  MAX_PIXELS = 50_000_000
  MAX_EDGE = 2048
  WEBP_QUALITY = 82
  TIMEOUT_SECONDS = 30

  class Unreadable < StandardError; end

  def initialize(post, detector: BearDetectorClient.new)
    @post = post
    @detector = detector
  end

  def call
    width, height = dimensions(@post.raw_path)
    return finish(:rejected, "too_large") if width * height > MAX_PIXELS

    output = PhotoStorage.uploads_dir.join("post-#{@post.id}-#{SecureRandom.hex(6)}.webp")
    run!("vipsthumbnail", @post.raw_path.to_s, "--size", "#{MAX_EDGE}x#{MAX_EDGE}>",
         "--export-profile", "srgb", "-o", "#{output}[Q=#{WEBP_QUALITY},strip]")
    out_width, out_height = dimensions(output)

    verdict = @detector.detect(File.binread(output))
    @post.bear_score = verdict.bear_score

    if verdict.is_bear
      key = PhotoStorage.new_key
      FileUtils.mv(output, PhotoStorage.media_path(key))
      @post.update!(status: "published", image_key: key, width: out_width, height: out_height, failure_reason: nil)
      delete_original
    else
      finish(:rejected, "no_bear")
    end
  rescue Unreadable, BearDetectorClient::Unreadable
    finish(:failed, "unreadable")
  ensure
    # Leaves the original in place only if the detector was unavailable, so a retry can use it.
    FileUtils.rm_f(output) if output
  end

  private
    def finish(status, reason)
      @post.update!(status:, failure_reason: reason)
      delete_original
    end

    def delete_original
      FileUtils.rm_f(@post.raw_path)
    end

    # vipsheader only parses the header, so a "decompression bomb" is caught
    # before any pixels are decoded.
    def dimensions(path)
      out = run!("vipsheader", "-f", "width", path.to_s) + " " + run!("vipsheader", "-f", "height", path.to_s)
      width, height = out.split.map { Integer(_1, exception: false) }
      raise Unreadable, "no dimensions" unless width&.positive? && height&.positive?
      [ width, height ]
    end

    def run!(*command)
      stdout, stderr, status = Open3.capture3("timeout", "--kill-after=5", TIMEOUT_SECONDS.to_s, *command)
      raise Unreadable, "#{command.first} failed (#{status.exitstatus}): #{stderr.strip.first(300)}" unless status.success?
      stdout
    end
end

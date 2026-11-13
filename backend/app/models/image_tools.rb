require "open3"

# libvips command-line helpers, always run under a hard timeout.
module ImageTools
  MAX_PIXELS = 50_000_000
  MAX_EDGE = 2048
  WEBP_QUALITY = 82
  TIMEOUT_SECONDS = 30

  class Unreadable < StandardError; end

  module_function

  # Reads only the header, so a "decompression bomb" is caught before any
  # pixels are decoded.
  def dimensions(path)
    out = run!("vipsheader", "-f", "width", path.to_s) + " " + run!("vipsheader", "-f", "height", path.to_s)
    width, height = out.split.map { Integer(_1, exception: false) }
    raise Unreadable, "no dimensions" unless width&.positive? && height&.positive?
    [ width, height ]
  end

  def too_large?(path)
    width, height = dimensions(path)
    width * height > MAX_PIXELS
  end

  # Auto-rotate, convert to sRGB, fit within MAX_EDGE, WebP with all metadata
  # (GPS, camera details...) stripped. Returns the output's [width, height].
  def to_webp(source, destination)
    run!("vipsthumbnail", source.to_s, "--size", "#{MAX_EDGE}x#{MAX_EDGE}>",
         "--export-profile", "srgb", "-o", "#{destination}[Q=#{WEBP_QUALITY},strip]")
    dimensions(destination)
  end

  def run!(*command)
    stdout, stderr, status = Open3.capture3("timeout", "--kill-after=5", TIMEOUT_SECONDS.to_s, *command)
    raise Unreadable, "#{command.first} failed (#{status.exitstatus}): #{stderr.strip.first(300)}" unless status.success?
    stdout
  end
end

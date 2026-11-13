# Where photos live.
#
#   uploads_dir - originals waiting for the worker (shared web <-> worker volume)
#   media_dir   - processed WebPs. With local storage they're served from here
#                 at /media (Caddy in prod, Rails in dev). With R2 they wait
#                 here until the web process uploads them, then get deleted.
#
# STORAGE_BACKEND=r2 sends published photos to Cloudflare R2 (docs/r2-setup.md).
module PhotoStorage
  class << self
    def r2?
      ENV["STORAGE_BACKEND"] == "r2" && !Rails.env.test?
    end

    def uploads_dir
      dir(ENV.fetch("UPLOADS_DIR") { Rails.root.join("storage/uploads") })
    end

    def media_dir
      dir(ENV.fetch("MEDIA_DIR") { Rails.root.join("public/media") })
    end

    def media_path(key)
      media_dir.join("#{key}.webp")
    end

    # Object key in the bucket. Non-production environments get their own
    # folder (e.g. "development/") so test photos are easy to find and delete.
    def r2_key(key)
      prefix = ENV.fetch("R2_KEY_PREFIX") { Rails.env.production? ? "" : "#{Rails.env}/" }
      "#{prefix}#{key}.webp"
    end

    def url_for(key, storage)
      if storage == "r2"
        "#{ENV.fetch("R2_PUBLIC_URL").chomp("/")}/#{r2_key(key)}"
      else
        "/media/#{key}.webp"
      end
    end

    def new_key
      SecureRandom.alphanumeric(32)
    end

    private
      def dir(path)
        Pathname(path).tap(&:mkpath)
      end
  end
end

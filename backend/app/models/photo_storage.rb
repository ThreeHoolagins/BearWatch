# Where photos live on disk.
#
#   uploads_dir - originals waiting for the worker (shared web <-> worker volume)
#   media_dir   - processed WebPs served at /media (Caddy in prod, Rails in dev)
#
# Cloudflare R2 plugs in here later (see docs/r2-setup.md).
module PhotoStorage
  class << self
    def uploads_dir
      dir(ENV.fetch("UPLOADS_DIR") { Rails.root.join("storage/uploads") })
    end

    def media_dir
      dir(ENV.fetch("MEDIA_DIR") { Rails.root.join("public/media") })
    end

    def media_path(key)
      media_dir.join("#{key}.webp")
    end

    def url_for(key)
      "/media/#{key}.webp"
    end

    def new_key
      SecureRandom.alphanumeric(32)
    end

    def delete(key)
      FileUtils.rm_f(media_path(key)) if key
    end

    private
      def dir(path)
        Pathname(path).tap(&:mkpath)
      end
  end
end

require "net/http"

# Posts historic public-domain bear photos (listed in db/archive_photos.yml)
# as the nps_historic_archive account, dated when they were taken, so every
# current bear ranks above them on the Global feed. Each photo is downloaded
# from its public source and then goes through the normal worker and
# detector like an upload. Safe to re-run: photos already posted (matched by
# source_url) are skipped, so adding entries to the list and running it
# again posts just the new ones.
#
#   bin/rails bearwatch:archive:import
class ArchiveImport
  NICKNAME = "nps_historic_archive"
  MANIFEST = Rails.root.join("db/archive_photos.yml")
  USER_AGENT = "BearWatch/1.0 (archive import; https://bearwatch.bigolbearstudios.com)"

  Entry = Data.define(:image_url, :source_url, :taken_on, :place_name, :latitude, :longitude, :credit, :avatar)

  def self.entries(manifest = MANIFEST)
    YAML.load_file(manifest, permitted_classes: [ Date ]).map do |entry|
      Entry.new(image_url: entry.fetch("image_url"), source_url: entry.fetch("source_url"), taken_on: taken_on(entry.fetch("taken_on")),
                place_name: entry.fetch("place_name"), latitude: entry.fetch("latitude"), longitude: entry.fetch("longitude"),
                credit: entry.fetch("credit"), avatar: entry["avatar"] == true)
    end
  end

  # A date, or just a year when that's all the archive knows (shown as the
  # year either way). Noon UTC so the day doesn't shift in any time zone.
  def self.taken_on(value)
    date = value.is_a?(Integer) ? Date.new(value, 7, 1) : Date.parse(value.to_s)
    date.to_time(:utc) + 12.hours
  end

  # fetch: url -> image bytes (swapped out in tests).
  def initialize(entries = self.class.entries, out: $stdout, fetch: method(:download))
    @entries = entries
    @out = out
    @fetch = fetch
  end

  def user
    @user ||= User.find_by(nickname: NICKNAME) || User.create!(nickname: NICKNAME)
  end

  def run
    # Failed means the worker hit a snag (not a rejection), so try those again.
    user.posts.failed.destroy_all
    done = user.posts.pluck(:source_url).to_set
    # Oldest first, so the newest photo has the highest id and leads the profile.
    fresh = @entries.reject { done.include?(_1.source_url) }.sort_by(&:taken_on)
    queued = fresh.count { post(_1) }
    @out.puts "Queued #{queued} archive photo#{"s" unless queued == 1} (#{@entries.size - fresh.size} already posted)."
    set_avatar
    report
  end

  private
    def post(entry)
      bytes = @fetch.call(entry.image_url)
      unless bytes.bytesize.between?(1, PhotoUpload::MAX_BYTES) && PhotoUpload.sniff(bytes)
        return @out.puts("  skipped (not an image under 12 MB): #{entry.image_url}")
      end

      post = user.posts.create!(place_name: entry.place_name, latitude: entry.latitude, longitude: entry.longitude,
                                credit: entry.credit, source_url: entry.source_url,
                                created_at: entry.taken_on, updated_at: Time.current)
      File.binwrite(post.raw_path, bytes)
      ProcessPhotoJob.perform_later(post.id)
      true
    rescue Net::HTTPExceptions, SocketError, SystemCallError, Timeout::Error => error
      @out.puts "  couldn't download #{entry.image_url}: #{error.message}"
      false
    end

    def download(url)
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
        response = http.get(uri.request_uri, "User-Agent" => USER_AGENT)
        response.value # raises unless 2xx
        response.body
      end
    end

    # The account can't sign in to pick an avatar, so the photo marked
    # `avatar: true` becomes it once the detector has published it.
    def set_avatar
      return if user.avatar_post
      source_url = @entries.find(&:avatar)&.source_url
      post = source_url && user.posts.published.find_by(source_url:)
      return unless post&.bear_x

      fit = [ post.width, post.height ].min / [ post.bear_w * post.width, post.bear_h * post.height, 1 ].max
      user.update!(avatar_post: post, avatar_zoom: (fit * 0.95).clamp(1.0, 4.0).round(2), avatar_x: post.bear_x, avatar_y: post.bear_y)
    end

    def report
      counts = user.posts.group(:status).count
      @out.puts "#{NICKNAME}: #{counts.map { "#{_2} #{_1}" }.join(", ")}" if counts.any?
      user.posts.where(status: %w[rejected failed]).find_each do |post|
        @out.puts "  #{post.status} (#{post.failure_reason}): #{post.source_url}"
      end
      if @entries.any?(&:avatar) && !user.reload.avatar_post
        @out.puts "Avatar not set yet: run this again once the photos are published."
      end
    end
end

class Post < ApplicationRecord
  STATUSES = %w[processing published rejected failed].freeze

  belongs_to :user
  has_one :fat_bear_win, dependent: :destroy

  # Removing a post (by an admin) also removes the stored photo.
  after_destroy_commit { DeletePhotoJob.perform_later(image_key, storage) if image_key }

  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :place_name, with: ->(name) { name.squish }
  # Never keep an exact spot: round to ~11 km before saving.
  normalizes :latitude, :longitude, with: ->(value) { value.to_d.round(1) }

  validates :place_name, presence: true, length: { maximum: 120 }
  validates :latitude, numericality: { in: -90..90 }
  validates :longitude, numericality: { in: -180..180 }

  scope :recent, -> { order(id: :desc) }
  scope :visible, -> { published.joins(:user).merge(User.active) }

  # Cursor pagination: newest first, `before` is the last id the client has.
  def self.page(before: nil, limit: 20)
    scope = recent.limit(limit)
    before.present? ? scope.where(id: ...before.to_i) : scope
  end

  # New bears wait this long before reaching the Global feed, so admins have a
  # chance to take spam down before everyone sees it.
  GLOBAL_DELAY = 10.minutes
  # A bear right next to you ranks as if it were this much newer. The
  # lift fades to nothing at NEARBY_MILES away.
  NEARBY_BOOST = 24.hours
  NEARBY_MILES = 500
  MILES_TO_METERS = 1609.344

  # Global feed: bears from anywhere, newest first, with nearby bears lifted
  # when a location is given. The rank is whole seconds, so the cursor is
  # "rank-id" and pages stay stable as new bears arrive. Archive photos
  # dated before 2000 have a negative rank ("-1234-56").
  def self.global_page(latitude: nil, longitude: nil, before: nil, limit: 20)
    rank = "TIMESTAMPDIFF(SECOND, '2000-01-01', posts.created_at)"
    if latitude && longitude
      distance = sanitize_sql_array([ "ST_Distance_Sphere(POINT(posts.longitude, posts.latitude), POINT(?, ?))", longitude, latitude ])
      rank = "#{rank} + FLOOR(#{NEARBY_BOOST.to_i} * GREATEST(0, 1 - #{distance} / #{NEARBY_MILES * MILES_TO_METERS}))"
    end

    scope = where(created_at: ..GLOBAL_DELAY.ago)
      .select("posts.*, #{rank} AS feed_rank")
      .order(Arel.sql("feed_rank DESC, posts.id DESC"))
      .limit(limit)
    cursor_rank, _, cursor_id = before.to_s.rpartition("-")
    cursor_rank, cursor_id = [ cursor_rank, cursor_id ].map { Integer(_1, exception: false) }
    scope = scope.where("(#{rank}, posts.id) < (?, ?)", cursor_rank, cursor_id) if cursor_rank && cursor_id
    scope
  end

  def feed_cursor
    "#{self[:feed_rank].to_i}-#{id}"
  end

  # Where the original upload waits for the worker. Deleted once processed.
  def raw_path
    PhotoStorage.uploads_dir.join("post-#{id}.upload")
  end

  def image_url
    PhotoStorage.url_for(image_key, storage) if published? && image_key
  end

  def as_json(*)
    {
      id:, status:, image_url:, width:, height:, place_name:,
      failure_reason: failed? || rejected? ? failure_reason : nil,
      created_at:,
      credit:, source_url:,
      user: user.public_json,
      fat_bear_win: fat_bear_win && { id: fat_bear_win.id, year: fat_bear_win.year },
      # Where the bear is, for starting the avatar picker on it.
      bear_box: bear_x && [ bear_x, bear_y, bear_w, bear_h ]
    }
  end
end

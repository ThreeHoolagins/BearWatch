class Post < ApplicationRecord
  STATUSES = %w[processing published rejected failed].freeze

  belongs_to :user

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

  MILES_TO_METERS = 1609.344
  # Published posts within `miles` of a point. A bounding box narrows the rows
  # (uses the status/latitude index) before the exact great-circle distance.
  def self.near(latitude, longitude, miles: 500)
    lat_span = miles / 69.0
    lng_span = miles / (69.0 * [ Math.cos(latitude * Math::PI / 180), 0.01 ].max)
    scope = where(latitude: (latitude - lat_span)..(latitude + lat_span))
    scope = scope.where(longitude: (longitude - lng_span)..(longitude + lng_span)) if lng_span < 180
    scope.where("ST_Distance_Sphere(POINT(posts.longitude, posts.latitude), POINT(?, ?)) <= ?",
                longitude, latitude, miles * MILES_TO_METERS)
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
      user: user.public_json,
      # Where the bear is, for starting the avatar picker on it.
      bear_box: bear_x && [ bear_x, bear_y, bear_w, bear_h ]
    }
  end
end

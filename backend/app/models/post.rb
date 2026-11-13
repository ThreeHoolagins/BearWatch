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

  scope :recent, -> { order(created_at: :desc, id: :desc) }

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
      user: { nickname: user.nickname }
    }
  end
end

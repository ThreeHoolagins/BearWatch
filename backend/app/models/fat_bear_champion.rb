class FatBearChampion < ApplicationRecord
  belongs_to :post, optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  normalizes :bear_name, :bear_number, :blurb, :credit, :link_text, with: ->(value) { value.squish.presence }
  normalizes :link_url, with: ->(value) { value.strip.presence }

  validates :year, numericality: { only_integer: true, greater_than_or_equal_to: FatBearWin::FIRST_YEAR,
                                   less_than_or_equal_to: ->(_) { Date.current.year + 1 } },
                   uniqueness: true
  validates :bear_name, presence: true, length: { maximum: 60 }
  validates :bear_number, length: { maximum: 10 }
  validates :blurb, length: { maximum: 200 }
  validates :credit, length: { maximum: 150 }
  validates :link_text, length: { maximum: 80 }
  validates :link_url, length: { maximum: 500 }, format: { with: %r{\Ahttps?://[^\s]+\z}i, message: "must start with http:// or https://" },
                       allow_nil: true
  validate :has_a_photo

  # The card everyone sees: the most recent year.
  def self.current
    order(year: :desc).first
  end

  def outside_photo?
    post_id.nil? && image_key.present?
  end

  def photo
    if post&.published?
      { url: post.image_url, width: post.width, height: post.height }
    elsif image_key
      { url: PhotoStorage.url_for(image_key, image_storage), width: image_width, height: image_height }
    end
  end

  def as_json(*)
    {
      year:, bear_name:, bear_number:, blurb:, photo:,
      source: post_id ? "post" : "outside",
      post_id:, poster: post&.published? ? post.user.public_json : nil,
      credit:, link_url:, link_text:
    }
  end

  private
    def has_a_photo
      errors.add(:base, "Pick a Bear Watch post or upload a photo.") unless post_id || image_key
    end
end

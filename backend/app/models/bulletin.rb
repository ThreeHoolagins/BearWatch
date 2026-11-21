# A house notice shown between posts in the feeds: inviting friends, the Ko-fi
# link, announcements. Admins manage them in the Ranger Station. Paid
# placements name a sponsor and are labeled "Sponsored" in the feed (FTC
# disclosure).
class Bulletin < ApplicationRecord
  KINDS = %w[link share].freeze

  belongs_to :updated_by, class_name: "User", optional: true

  after_destroy_commit { DeletePhotoJob.perform_later(image_key, image_storage) if image_key }

  normalizes :title, :body, :link_text, :sponsor, with: ->(value) { value.squish.presence }
  normalizes :link_url, with: ->(value) { value.strip.presence }

  validates :title, presence: true, length: { maximum: 80 }
  validates :body, presence: true, length: { maximum: 300 }
  validates :kind, inclusion: { in: KINDS }
  validates :link_text, presence: true, length: { maximum: 40 }
  validates :sponsor, length: { maximum: 60 }
  validates :link_url, length: { maximum: 500 }, format: { with: %r{\Ahttps?://[^\s]+\z}i, message: "must start with http:// or https://" },
                       allow_nil: true
  validates :link_url, presence: true, if: -> { kind == "link" }
  validates :position, numericality: { only_integer: true }

  scope :ordered, -> { order(:position, :id) }
  scope :live, -> { where(active: true).ordered }

  def photo
    return unless image_key

    { url: PhotoStorage.url_for(image_key, image_storage), width: image_width, height: image_height, logo: image_storage == "static" }
  end

  def as_json(*)
    { id:, title:, body:, kind:, link_url: kind == "link" ? link_url : nil, link_text:, sponsor:, photo:, active:, position: }
  end
end

class User < ApplicationRecord
  has_many :identities, dependent: :destroy
  has_many :posts, dependent: :destroy
  belongs_to :avatar_post, class_name: "Post", optional: true

  has_many :following_links, class_name: "Follow", foreign_key: :follower_id, dependent: :delete_all, inverse_of: :follower
  has_many :follower_links, class_name: "Follow", foreign_key: :followee_id, dependent: :delete_all, inverse_of: :followee
  has_many :followees, through: :following_links
  has_many :followers, through: :follower_links

  scope :active, -> { where(banned_at: nil) }

  normalizes :nickname, with: ->(nickname) { nickname.strip }

  validates :nickname,
    presence: { message: "Pick a nickname." },
    length: { minimum: 3, maximum: 20, too_short: "Use at least 3 characters.", too_long: "Use 20 characters or fewer." },
    format: { with: /\A[A-Za-z0-9_]+\z/, message: "Letters, numbers and underscores only." }
  validates :nickname, uniqueness: { case_sensitive: false, message: "Taken. Another bear watcher got there first." }, on: :create
  validate :nickname_allowed, on: :create

  def banned?
    banned_at.present?
  end

  def ban!(reason)
    update!(banned_at: Time.current, ban_reason: reason)
  end

  def unban!
    update!(banned_at: nil, ban_reason: nil)
  end

  def as_json(*)
    { id:, nickname:, is_admin:, banned: banned?, ban_reason: banned? ? ban_reason : nil, avatar: }
  end

  # The crop of one of their photos shown in the circle, or nil for the blank bear.
  def avatar
    post = avatar_post
    return unless post&.published? && post.user_id == id

    { url: post.image_url, width: post.width, height: post.height, zoom: avatar_zoom || 1.0, x: avatar_x || 0.5, y: avatar_y || 0.5 }
  end

  # How bear watchers see each other (no ban details, no admin flag).
  def public_json
    { nickname:, avatar:, ranger: is_admin }
  end

  # Admin panel view.
  def admin_json
    { id:, nickname:, avatar:, ranger: is_admin, banned: banned?, ban_reason:, banned_at:, created_at:,
      posts_count: posts.published.count }
  end

  private
    def nickname_allowed
      errors.add(:nickname, "That nickname isn't allowed.") if nickname.present? && NicknameFilter.blocked?(nickname)
    end
end

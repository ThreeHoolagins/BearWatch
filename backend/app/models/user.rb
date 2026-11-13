class User < ApplicationRecord
  has_many :identities, dependent: :destroy
  has_many :posts, dependent: :destroy

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
    { id:, nickname:, is_admin:, banned: banned?, ban_reason: banned? ? ban_reason : nil }
  end

  private
    def nickname_allowed
      errors.add(:nickname, "That nickname isn't allowed.") if nickname.present? && NicknameFilter.blocked?(nickname)
    end
end

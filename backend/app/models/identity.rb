class Identity < ApplicationRecord
  PROVIDERS = %w[google_oauth2 github developer].freeze

  belongs_to :user

  validates :provider, inclusion: { in: PROVIDERS }
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :user_id }
end

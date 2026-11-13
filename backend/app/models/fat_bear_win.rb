class FatBearWin < ApplicationRecord
  FIRST_YEAR = 2014 # Fat Bear Week started in 2014

  belongs_to :post
  belongs_to :awarded_by, class_name: "User", optional: true

  validates :year, numericality: { only_integer: true, greater_than_or_equal_to: FIRST_YEAR,
                                   less_than_or_equal_to: ->(_) { Date.current.year + 1 } },
                   uniqueness: { message: "already has a winner" }
  validate :post_is_published

  def as_json(*)
    { id:, year:, post: }
  end

  private
    def post_is_published
      errors.add(:post, "must be a published post") unless post&.published?
    end
end

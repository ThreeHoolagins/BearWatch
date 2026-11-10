require "test_helper"

class UserTest < ActiveSupport::TestCase
  def nickname_errors(nickname)
    user = User.new(nickname:)
    user.valid?
    user.errors.where(:nickname).map(&:message)
  end

  test "accepts a valid nickname" do
    assert_empty nickname_errors("otis_superfan")
  end

  test "enforces 3 to 20 characters" do
    assert_includes nickname_errors("ab"), "Use at least 3 characters."
    assert_includes nickname_errors("a" * 21), "Use 20 characters or fewer."
  end

  test "allows only letters, numbers and underscores" do
    assert_includes nickname_errors("bear watcher"), "Letters, numbers and underscores only."
    assert_includes nickname_errors("bear-watcher"), "Letters, numbers and underscores only."
  end

  test "nicknames are unique regardless of case" do
    User.create!(nickname: "Grizzwald")
    assert_includes nickname_errors("grizzwald"), "Taken. Another bear watcher got there first."
  end

  test "rejects blocked nicknames" do
    assert_includes nickname_errors("bearwatch_admin"), "That nickname isn't allowed."
  end

  test "ban and unban" do
    user = User.create!(nickname: "troll_bear_99")
    user.ban!("Photos with people in them.")
    assert user.banned?
    assert_equal "Photos with people in them.", user.as_json[:ban_reason]

    user.unban!
    assert_not user.banned?
    assert_nil user.as_json[:ban_reason]
  end
end

require "test_helper"

class NicknameFilterTest < ActiveSupport::TestCase
  test "allows ordinary bear names" do
    %w[otis_superfan grizzwald trail_mix_tina ram_ranger Cassidy grape_bear button_nose bass_fan].each do |name|
      assert_not NicknameFilter.blocked?(name), "#{name} should be allowed"
    end
  end

  test "blocks profanity, including leetspeak and underscores" do
    %w[shitbear sh1tbear s_h_i_t_bear fuckbears].each do |name|
      assert NicknameFilter.blocked?(name), "#{name} should be blocked"
    end
  end

  test "blocks reserved words anywhere" do
    %w[admin bear_admin BearWatchTeam moderator99].each do |name|
      assert NicknameFilter.blocked?(name), "#{name} should be blocked"
    end
  end

  test "blocks plain reserved words only as the whole nickname" do
    %w[ranger R4nger staff_ official_1 mod].each do |name|
      assert NicknameFilter.blocked?(name), "#{name} should be blocked"
    end
    %w[ram_ranger bear_staff modelbear].each do |name|
      assert_not NicknameFilter.blocked?(name), "#{name} should be allowed"
    end
  end
end

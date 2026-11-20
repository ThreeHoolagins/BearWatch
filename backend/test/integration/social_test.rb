require "test_helper"

class SocialTest < ActionDispatch::IntegrationTest
  FORT_COLLINS = [ 40.6, -105.1 ]
  ESTES_PARK = [ 40.4, -105.5 ]      # ~25 miles away
  YELLOWSTONE = [ 44.4, -110.6 ]     # ~400 miles away
  KATMAI = [ 58.6, -155.0 ]          # ~2,700 miles away

  setup do
    @me = User.create!(nickname: "grizzwald")
    @otis = User.create!(nickname: "otis_superfan")
    @tina = User.create!(nickname: "trail_mix_tina")
    sign_in_as(@me)
  end

  # Bears are an hour old by default so they've cleared the Global feed delay.
  def bear(user, (lat, lng), status: "published", created_at: 1.hour.ago, **attrs)
    user.posts.create!(place_name: "Somewhere", latitude: lat, longitude: lng, status:, image_key: SecureRandom.hex(8), created_at:, **attrs)
  end

  def ids(path, params = {})
    get path, params: params
    assert_response :ok
    response.parsed_body["posts"].map { _1["id"] }
  end

  test "global feed shows published bears from anywhere, newest first" do
    old = bear(@otis, KATMAI, created_at: 2.hours.ago)
    near = bear(@otis, ESTES_PARK)
    bear(@tina, ESTES_PARK, status: "rejected")
    bear(@tina, ESTES_PARK, status: "processing")

    assert_equal [ near.id, old.id ], ids("/api/feed/global")
  end

  test "global feed lifts bears near you" do
    far_new = bear(@tina, KATMAI, created_at: 1.hour.ago)
    near_old = bear(@otis, ESTES_PARK, created_at: 20.hours.ago)
    medium_old = bear(@tina, YELLOWSTONE, created_at: 21.hours.ago)
    far_old = bear(@otis, KATMAI, created_at: 22.hours.ago)

    assert_equal [ far_new.id, near_old.id, medium_old.id, far_old.id ], ids("/api/feed/global")
    assert_equal [ near_old.id, far_new.id, medium_old.id, far_old.id ],
                 ids("/api/feed/global", lat: FORT_COLLINS[0], lng: FORT_COLLINS[1])
  end

  test "global feed holds back bears for their first 10 minutes" do
    bear(@otis, ESTES_PARK, created_at: 5.minutes.ago)
    settled = bear(@otis, ESTES_PARK, created_at: 11.minutes.ago)

    assert_equal [ settled.id ], ids("/api/feed/global")
  end

  test "global feed rejects a bad location" do
    get "/api/feed/global", params: { lat: 200, lng: 0 }
    assert_response :unprocessable_entity
  end

  test "banned users' bears disappear from feeds and their profile 404s" do
    bear(@otis, ESTES_PARK)
    @otis.ban!("Testing")

    assert_empty ids("/api/feed/global", lat: FORT_COLLINS[0], lng: FORT_COLLINS[1])
    get "/api/users/otis_superfan"
    assert_response :not_found
  end

  test "feeds paginate with a cursor" do
    posts = 25.times.map { |i| bear(@otis, i.even? ? ESTES_PARK : KATMAI, created_at: (30 - i).hours.ago) }
    params = { lat: FORT_COLLINS[0], lng: FORT_COLLINS[1] }
    get "/api/feed/global", params: params
    first = response.parsed_body
    assert_equal 20, first["posts"].size

    rest = ids("/api/feed/global", **params, before: first["next_before"])
    assert_equal 5, rest.size
    assert_equal posts.map(&:id).sort, (first["posts"].map { _1["id"] } + rest).sort
  end

  test "follow, see their bears in Following, unfollow" do
    otis_bear = bear(@otis, KATMAI)
    bear(@tina, KATMAI)

    assert_empty ids("/api/feed/following")

    api :post, "/api/users/otis_superfan/follow"
    assert_equal({ "following" => true, "followers_count" => 1 }, response.parsed_body)
    api :post, "/api/users/otis_superfan/follow" # twice is fine
    assert_equal 1, @otis.follower_links.count

    assert_equal [ otis_bear.id ], ids("/api/feed/following"), "distance doesn't matter for Following"

    get "/api/users/otis_superfan"
    profile = response.parsed_body["user"]
    assert_equal [ true, 1, 0, false ], profile.values_at("following", "followers_count", "following_count", "me")

    api :delete, "/api/users/otis_superfan/follow"
    assert_equal false, response.parsed_body["following"]
    assert_empty ids("/api/feed/following")
  end

  test "can't follow yourself" do
    api :post, "/api/users/grizzwald/follow"
    assert_response :unprocessable_entity
  end

  test "pick a bear face from your own photo, then go back to the blank bear" do
    photo = bear(@me, ESTES_PARK, width: 800, height: 600)

    api :put, "/api/me/avatar", post_id: photo.id, zoom: 9, x: 0.3, y: -2
    avatar = response.parsed_body.dig("user", "avatar")
    assert_equal [ 4.0, 0.3, 0.0 ], avatar.values_at("zoom", "x", "y"), "clamped to sensible ranges"
    assert_equal [ 800, 600 ], avatar.values_at("width", "height")

    # Shows up on their posts in feeds.
    get "/api/users/grizzwald/posts"
    assert_equal photo.image_url, response.parsed_body["posts"].first.dig("user", "avatar", "url")

    api :put, "/api/me/avatar", post_id: nil
    assert_nil response.parsed_body.dig("user", "avatar")
  end

  test "can't use someone else's photo as your bear face" do
    api :put, "/api/me/avatar", post_id: bear(@otis, ESTES_PARK).id
    assert_response :unprocessable_entity
  end
end

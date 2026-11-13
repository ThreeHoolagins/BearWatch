require "test_helper"

class AdminTest < ActionDispatch::IntegrationTest
  include TestImages
  include ActiveJob::TestHelper

  setup do
    @ranger = User.create!(nickname: "head_ranger_1", is_admin: true)
    @otis = User.create!(nickname: "otis_superfan")
    @troll = User.create!(nickname: "troll_bear_99")
    sign_in_as(@ranger)
  end

  def bear(user, **attrs)
    user.posts.create!(place_name: "Katmai National Park, AK", latitude: 58.6, longitude: -155.0, status: "published",
                       image_key: SecureRandom.hex(8), width: 800, height: 600, **attrs)
  end

  test "non-admins are kept out of every admin endpoint" do
    api :delete, "/api/session"
    sign_in_as(@otis)

    [ [ :get, "/api/admin/users" ], [ :post, "/api/admin/users/troll_bear_99/ban" ], [ :get, "/api/admin/wins" ],
      [ :put, "/api/admin/champion/2026" ], [ :delete, "/api/admin/posts/1" ] ].each do |method, path|
      api method, path
      assert_response :forbidden, "#{method} #{path}"
    end
    assert_not @troll.reload.banned?
  end

  test "search users, ban with a reason, unban" do
    get "/api/admin/users", params: { q: "troll" }
    assert_equal [ "troll_bear_99" ], response.parsed_body["users"].map { _1["nickname"] }

    api :post, "/api/admin/users/troll_bear_99/ban", reason: ""
    assert_response :unprocessable_entity

    api :post, "/api/admin/users/troll_bear_99/ban", reason: "Uploaded photos of people instead of bears."
    assert_response :ok
    assert_equal "Uploaded photos of people instead of bears.", @troll.reload.ban_reason

    api :delete, "/api/admin/users/troll_bear_99/ban"
    assert_not @troll.reload.banned?
  end

  test "admins can't ban themselves or other admins" do
    User.create!(nickname: "other_ranger", is_admin: true)
    api :post, "/api/admin/users/head_ranger_1/ban", reason: "oops"
    assert_response :unprocessable_entity
    api :post, "/api/admin/users/other_ranger/ban", reason: "oops"
    assert_response :unprocessable_entity
  end

  test "award a Fat Bear Week win, one per year, shown on the post and profile" do
    winner = bear(@otis)
    api :post, "/api/admin/wins", post_id: winner.id, year: 2025
    assert_response :created

    api :post, "/api/admin/wins", post_id: bear(@troll).id, year: 2025
    assert_response :unprocessable_entity
    assert_match "already has a winner", response.parsed_body["message"]

    api :post, "/api/admin/wins", post_id: winner.id, year: 2013
    assert_response :unprocessable_entity, "Fat Bear Week started in 2014"

    get "/api/users/otis_superfan/posts"
    assert_equal 2025, response.parsed_body["posts"].first.dig("fat_bear_win", "year")
    get "/api/users/otis_superfan"
    assert_equal 1, response.parsed_body.dig("user", "fat_bear_wins")

    api :delete, "/api/admin/wins/#{FatBearWin.last.id}"
    get "/api/users/otis_superfan"
    assert_equal 0, response.parsed_body.dig("user", "fat_bear_wins")
  end

  test "champion card from a Bear Watch post" do
    post_ = bear(@otis)
    api :put, "/api/admin/champion/2026", source: "post", post_id: post_.id, bear_name: "Big Biscuit", bear_number: "999",
                                          blurb: "Crowned the fattest bear."
    assert_response :ok

    get "/api/champion"
    champion = response.parsed_body["champion"]
    assert_equal [ 2026, "Big Biscuit", "post", "otis_superfan" ], [ champion["year"], champion["bear_name"], champion["source"], champion.dig("poster", "nickname") ]
    assert_equal post_.image_url, champion.dig("photo", "url")
  end

  test "champion card from an outside photo with credit and link, re-encoded and stripped" do
    api :put, "/api/admin/champion/2026", { source: "outside", photo: uploaded(make_image("jpg", width: 3000, height: 2000)),
                                            bear_name: "Chunk", credit: "Photo: NPS / A. Photographer",
                                            link_url: "https://explore.org/fat-bear-week", link_text: "Fat Bear Week" }, multipart: true
    assert_response :ok
    champion = FatBearChampion.find_by!(year: 2026)
    assert_equal [ 2048, 1365 ], [ champion.image_width, champion.image_height ]
    assert_equal :webp, PhotoUpload.sniff(File.binread(PhotoStorage.media_path(champion.image_key), 16))

    # Editing the text keeps the photo.
    api :put, "/api/admin/champion/2026", source: "outside", bear_name: "Chunk", blurb: "New blurb"
    assert_equal champion.image_key, champion.reload.image_key

    # Unsafe links are refused.
    api :put, "/api/admin/champion/2026", source: "outside", bear_name: "Chunk", link_url: "javascript:alert(1)"
    assert_response :unprocessable_entity
  end

  test "a champion card needs a photo" do
    api :put, "/api/admin/champion/2026", source: "outside", bear_name: "Chunk"
    assert_response :unprocessable_entity
    assert_equal "Pick a Bear Watch post or upload a photo.", response.parsed_body["message"]
  end

  test "take down a post: gone from feeds, photo deleted" do
    post_ = bear(@troll)
    PhotoStorage.media_path(post_.image_key).write("pretend photo")

    assert_enqueued_with(job: DeletePhotoJob, args: [ post_.image_key, "local" ]) do
      api :delete, "/api/admin/posts/#{post_.id}"
    end
    assert_response :no_content
    assert_not Post.exists?(post_.id)

    perform_enqueued_jobs(only: DeletePhotoJob)
    assert_not PhotoStorage.media_path(post_.image_key).exist?
  end
end

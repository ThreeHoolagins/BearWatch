require "test_helper"

class PostsTest < ActionDispatch::IntegrationTest
  include TestImages
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(nickname: "grizzwald")
    sign_in_as(@user)
  end

  def upload(file = uploaded(make_image("jpg")), place: "Katmai National Park, AK", latitude: 58.5534, longitude: -155.0412)
    api :post, "/api/posts", { photo: file, place_name: place, latitude:, longitude: }, multipart: true
  end

  test "accepts a photo, rounds the location, and queues processing" do
    assert_enqueued_with(job: ProcessPhotoJob) { upload }
    assert_response :accepted

    post = Post.last
    assert post.processing?
    assert_equal [ 58.6, -155.0 ], [ post.latitude.to_f, post.longitude.to_f ], "rounded to ~11 km"
    assert_equal "Katmai National Park, AK", post.place_name
    assert File.exist?(post.raw_path)
  end

  test "the poster can poll their post while it's processing; others can't see it" do
    upload
    id = response.parsed_body.dig("post", "id")
    get "/api/posts/#{id}"
    assert_equal "processing", response.parsed_body.dig("post", "status")

    other = User.create!(nickname: "otis_superfan")
    api :delete, "/api/session"
    sign_in_as(other)
    get "/api/posts/#{id}"
    assert_response :not_found
  end

  test "rejects a renamed non-image without queueing anything" do
    path = scratch_file("notes.jpg", "just text")
    assert_no_enqueued_jobs { upload(uploaded(path)) }
    assert_response :unprocessable_entity
    assert_equal "That file isn't the kind of image its name says it is.", response.parsed_body["message"]
  end

  test "requires a location" do
    upload(latitude: nil)
    assert_response :unprocessable_entity
    assert_equal "Pick where you saw this bear.", response.parsed_body["message"]
  end

  test "one accepted bear per minute; rejected photos don't count" do
    upload
    assert_response :accepted
    upload
    assert_response :too_many_requests
    assert_match(/One bear a minute/, response.parsed_body["message"])

    Post.update_all(status: "rejected")
    upload
    assert_response :accepted
  end

  test "out of honey: uploads stop with the ranger message and one Discord alert goes out" do
    ENV["R2_STORAGE_LIMIT_GB"] = "0"
    ENV["DISCORD_WEBHOOK_URL"] = "https://discord.com/api/webhooks/1/test"
    stubbing(PhotoStorage, :r2?, true) do
      assert_enqueued_jobs(1, only: DiscordAlertJob) do
        2.times do
          assert_no_enqueued_jobs(only: ProcessPhotoJob) { upload }
          assert_response :service_unavailable
          assert_equal "Oops! Ran out of honey. A ranger needs to fix this.", response.parsed_body["message"]
        end
      end
    end
    assert_equal 0, Post.count
  ensure
    ENV.delete("R2_STORAGE_LIMIT_GB")
    ENV.delete("DISCORD_WEBHOOK_URL")
  end

  test "posters can delete their own bears, but not anyone else's" do
    mine = @user.posts.create!(place_name: "Estes Park, CO", latitude: 40.4, longitude: -105.5, status: "published", image_key: "mine")
    theirs = User.create!(nickname: "otis_superfan").posts.create!(place_name: "Estes Park, CO", latitude: 40.4,
                                                                    longitude: -105.5, status: "published", image_key: "theirs")

    assert_enqueued_with(job: DeletePhotoJob, args: [ "mine", "local" ]) { api :delete, "/api/posts/#{mine.id}" }
    assert_response :no_content
    assert_not Post.exists?(mine.id)

    api :delete, "/api/posts/#{theirs.id}"
    assert_response :not_found
    assert Post.exists?(theirs.id)
  end

  test "banned and signed-out users can't upload" do
    @user.ban!("Testing")
    upload
    assert_response :forbidden

    api :delete, "/api/session"
    upload
    assert_response :unauthorized
  end

  test "profile grid lists only published posts" do
    published = @user.posts.create!(place_name: "Estes Park, CO", latitude: 40.4, longitude: -105.5, status: "published", image_key: "abc")
    @user.posts.create!(place_name: "Estes Park, CO", latitude: 40.4, longitude: -105.5, status: "rejected")

    get "/api/users/grizzwald/posts"
    assert_equal [ published.id ], response.parsed_body["posts"].map { _1["id"] }
    assert_equal "/media/abc.webp", response.parsed_body["posts"].first["image_url"]
  end
end

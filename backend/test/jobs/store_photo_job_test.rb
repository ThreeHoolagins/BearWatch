require "test_helper"

class StorePhotoJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper
  include TestImages

  class FakeR2
    attr_reader :puts

    def initialize = @puts = []
    def put_webp(key, path) = @puts << [ key, File.size(path) ]
  end

  setup do
    @user = User.create!(nickname: "grizzwald")
    @key = PhotoStorage.new_key
    FileUtils.cp(make_image("webp"), PhotoStorage.media_path(@key))
    @post = @user.posts.create!(place_name: "Katmai National Park, AK", latitude: 58.5, longitude: -155.1, image_key: @key)
    @r2 = FakeR2.new
    ENV["ALERT_EMAIL"] = "ranger@example.com"
  end

  teardown do
    ENV.delete("ALERT_EMAIL")
    ENV.delete("R2_STORAGE_LIMIT_GB")
  end

  def perform
    stubbing(PhotoStorage, :r2?, true) do
      stubbing(R2Client, :new, @r2) { StorePhotoJob.perform_now(@post.id) }
    end
    @post.reload
  end

  test "uploads to R2, publishes, and removes the local copy" do
    perform

    assert @post.published?
    assert_equal "r2", @post.storage
    assert_equal [ [ PhotoStorage.r2_key(@key), @post.image_bytes ] ], @r2.puts
    assert_not PhotoStorage.media_path(@key).exist?
  end

  test "out of honey: doesn't upload, fails the post, emails the ranger" do
    ENV["R2_STORAGE_LIMIT_GB"] = "0"
    assert_enqueued_emails(1) { perform }

    assert_equal [ "failed", "out_of_storage" ], [ @post.status, @post.failure_reason ]
    assert_empty @r2.puts
    assert_not PhotoStorage.media_path(@key).exist?
  end
end

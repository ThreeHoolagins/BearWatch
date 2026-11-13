require "test_helper"

class PhotoProcessorTest < ActiveSupport::TestCase
  include TestImages

  setup do
    @user = User.create!(nickname: "grizzwald")
  end

  def post_with(path)
    post = @user.posts.create!(place_name: "Katmai National Park, AK", latitude: 58.55, longitude: -155.04)
    FileUtils.cp(path, post.raw_path)
    post
  end

  test "publishes a bear: WebP, metadata stripped, original deleted" do
    source = make_image_with_exif(width: 3000, height: 1500)
    assert_match(/exif-data/, `vipsheader -a #{source}`, "source really has EXIF")
    post = post_with(source)
    detector = FakeDetector.new(is_bear: true, bear_score: 0.93)

    PhotoProcessor.new(post, detector:).call
    post.reload

    assert post.published?
    assert_equal 1, detector.calls
    assert_in_delta 0.93, post.bear_score
    assert_equal [ 2048, 1024 ], [ post.width, post.height ], "fits within 2048px, keeps aspect ratio"
    media = PhotoStorage.media_path(post.image_key)
    assert_equal :webp, PhotoUpload.sniff(File.binread(media, 16))
    assert_no_match(/exif|xmp|icc/i, `vipsheader -a #{media}`.lines.grep(/-data/).join, "no metadata blocks left")
    assert_not File.exist?(post.raw_path), "original deleted"
    assert_equal "/media/#{post.image_key}.webp", post.image_url
  end

  test "rejects a photo without a bear and keeps nothing" do
    post = post_with(make_image("png"))
    PhotoProcessor.new(post, detector: FakeDetector.new(is_bear: false, bear_score: 0.3)).call
    post.reload

    assert post.rejected?
    assert_equal "no_bear", post.failure_reason
    assert_nil post.image_key
    assert_not File.exist?(post.raw_path)
  end

  test "rejects images over the pixel limit from the header alone" do
    post = post_with(make_image("png", width: 8000, height: 7000))
    detector = FakeDetector.new
    PhotoProcessor.new(post, detector:).call

    assert_equal [ "rejected", "too_large" ], [ post.reload.status, post.failure_reason ]
    assert_equal 0, detector.calls, "never decoded or sent to the detector"
  end

  test "fails unreadable files that only look like images" do
    path = scratch_file("broken.jpg", ["FFD8FFE0"].pack("H*") + SecureRandom.random_bytes(2000))
    post = post_with(path)
    PhotoProcessor.new(post, detector: FakeDetector.new).call

    assert_equal [ "failed", "unreadable" ], [ post.reload.status, post.failure_reason ]
    assert_not File.exist?(post.raw_path)
  end

  test "keeps the original for a retry when the detector is down" do
    post = post_with(make_image("jpg"))
    detector = FakeDetector.new(error: BearDetectorClient::Unavailable.new("down"))

    assert_raises(BearDetectorClient::Unavailable) { PhotoProcessor.new(post, detector:).call }
    assert post.reload.processing?
    assert File.exist?(post.raw_path)
  end
end

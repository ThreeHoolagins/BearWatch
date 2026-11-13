require "test_helper"

class PhotoUploadTest < ActiveSupport::TestCase
  include TestImages

  def error_for(file)
    upload = PhotoUpload.new(file)
    upload.valid?
    upload.errors.full_messages.first
  end

  test "accepts real JPG, PNG and WebP files" do
    %w[jpg png webp].each do |format|
      assert_nil error_for(uploaded(make_image(format))), "#{format} should be accepted"
    end
  end

  test "accepts .jpeg and uppercase extensions" do
    assert_nil error_for(uploaded(make_image("jpg"), filename: "BEAR.JPEG"))
  end

  test "rejects a file whose bytes don't match its extension" do
    assert_equal "That file isn't the kind of image its name says it is.",
      error_for(uploaded(make_image("png"), filename: "bear.jpg"))
  end

  test "rejects a script renamed to .jpg" do
    path = scratch_file("evil.jpg", "#!/bin/sh echo not a photo")
    assert_equal "That file isn't the kind of image its name says it is.", error_for(uploaded(path))
  end

  test "rejects unsupported extensions" do
    assert_equal "Use a JPG, PNG, WebP or HEIC photo.", error_for(uploaded(make_image("jpg"), filename: "bear.gif"))
  end

  test "rejects files over 12 MB" do
    path = scratch_file("huge.jpg", ["FFD8FF"].pack("H*") + ("0" * (PhotoUpload::MAX_BYTES + 1)))
    assert_equal "That photo is over 12 MB. Try a smaller one.", error_for(uploaded(path))
  end

  test "requires a file" do
    assert_equal "Choose a photo to upload.", error_for(nil)
  end

  test "recognises HEIC magic bytes" do
    assert_equal :heif, PhotoUpload.sniff("\x00\x00\x00\x18ftypheic\x00\x00".b)
    assert_nil PhotoUpload.sniff("\x00\x00\x00\x18ftypisom".b), "MP4 videos are not photos"
  end
end

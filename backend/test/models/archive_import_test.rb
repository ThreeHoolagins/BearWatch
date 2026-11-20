require "test_helper"

class ArchiveImportTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include TestImages

  def entry(source, taken_on, avatar: false)
    ArchiveImport::Entry.new(image_url: "https://example.test/#{source}.jpg", source_url: "https://example.test/#{source}",
                             taken_on: ArchiveImport.taken_on(taken_on), place_name: "Yellowstone National Park, WY",
                             latitude: 44.6, longitude: -110.5, credit: "NPS Photo by Bryan Harry, #{taken_on}", avatar:)
  end

  def import(entries, fetch: ->(_url) { File.binread(make_image) })
    out = StringIO.new
    ArchiveImport.new(entries, out:, fetch:).run
    out.string
  end

  test "posts each photo as the archive account, dated when it was taken, through the normal worker" do
    entries = [ entry("grizzly", 1966), entry("dixon", "1913-09-19") ]
    assert_enqueued_jobs(2, only: ProcessPhotoJob) { import(entries) }

    user = User.find_by!(nickname: "nps_historic_archive")
    older, newer = user.posts.order(:id).to_a
    assert_equal Time.utc(1913, 9, 19, 12), older.created_at
    assert_equal Time.utc(1966, 7, 1, 12), newer.created_at
    assert_equal "NPS Photo by Bryan Harry, 1966", newer.credit
    assert newer.processing?
    assert newer.raw_path.exist?
    assert_equal "https://example.test/grizzly", newer.as_json[:source_url]
  end

  test "running it again skips photos already posted and retries failed ones" do
    entries = [ entry("one", 1964), entry("two", 1970) ]
    import(entries)
    user = User.find_by!(nickname: "nps_historic_archive")
    user.posts.find_by!(source_url: "https://example.test/one").update!(status: "rejected", failure_reason: "no_bear")
    user.posts.find_by!(source_url: "https://example.test/two").update!(status: "failed", failure_reason: "detector_unavailable")

    output = nil
    assert_enqueued_jobs(1, only: ProcessPhotoJob) { output = import(entries) }
    assert_match "Queued 1 archive photo (1 already posted)", output
    assert_equal %w[processing rejected], user.posts.order(:status).pluck(:status)
  end

  test "skips downloads that aren't images" do
    output = nil
    assert_no_enqueued_jobs { output = import([ entry("page", 1964) ], fetch: ->(_url) { "<html>not found</html>" }) }
    assert_match "skipped", output
    assert_empty User.find_by!(nickname: "nps_historic_archive").posts
  end

  test "uses the marked photo as the avatar once it's published" do
    entries = [ entry("face", 1966, avatar: true) ]
    import(entries)
    user = User.find_by!(nickname: "nps_historic_archive")
    assert_nil user.avatar_post

    user.posts.first.update!(status: "published", image_key: "abc", width: 2000, height: 1300, bear_x: 0.5, bear_y: 0.4, bear_w: 0.3, bear_h: 0.5)
    import(entries)
    assert_equal user.posts.first, user.reload.avatar_post
  end
end

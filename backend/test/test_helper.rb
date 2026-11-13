ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

ENV["UPLOADS_DIR"] ||= Rails.root.join("tmp/test-uploads").to_s
ENV["MEDIA_DIR"] ||= Rails.root.join("tmp/test-media").to_s

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers. Each worker gets its own
    # photo folders because post ids repeat across the per-worker databases.
    parallelize(workers: :number_of_processors)
    parallelize_setup do |worker|
      ENV["UPLOADS_DIR"] = Rails.root.join("tmp/test-uploads-#{worker}").to_s
      ENV["MEDIA_DIR"] = Rails.root.join("tmp/test-media-#{worker}").to_s
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all
  end
end

# Temporarily replace a class method (minitest/mock isn't bundled with Minitest 6).
#   stubbing(PhotoStorage, :r2?, true) { ... }
module Stubbing
  def stubbing(target, name, value)
    original = target.method(name)
    target.define_singleton_method(name) { |*| value }
    yield
  ensure
    target.define_singleton_method(name, original)
  end
end

ActiveSupport::TestCase.include(Stubbing)

# Test images are generated with the libvips CLI instead of committing binaries.
module TestImages
  DIR = Rails.root.join("tmp/test-images")

  # A small image in the given format ("jpg", "png", "webp").
  def make_image(format = "jpg", width: 120, height: 80)
    path = DIR.join("#{width}x#{height}-#{SecureRandom.hex(4)}.#{format}")
    DIR.mkpath
    system("vips", "black", path.to_s, width.to_s, height.to_s, "--bands", "3", exception: true)
    path
  end

  # A JPEG carrying an EXIF block (a minimal TIFF header), standing in for a
  # phone photo with GPS and camera data.
  def make_image_with_exif(**size)
    path = make_image("jpg", **size)
    bytes = File.binread(path)
    tiff = ["4D4D002A000000080000000000000000"].pack("H*")
    segment = ["FFE1"].pack("H*") + [ tiff.bytesize + 8 ].pack("n") + "Exif".b + ["0000"].pack("H*") + tiff
    File.binwrite(path, bytes[0, 2] + segment + bytes[2..])
    path
  end

  # A uniquely named scratch file with the given contents.
  def scratch_file(name, contents)
    DIR.mkpath
    DIR.join("#{SecureRandom.hex(4)}-#{name}").tap { |path| File.binwrite(path, contents) }
  end

  def uploaded(path, filename: File.basename(path), type: "application/octet-stream")
    Rack::Test::UploadedFile.new(path, type, true, original_filename: filename)
  end
end

# Stands in for the detector container.
class FakeDetector
  attr_reader :calls

  def initialize(is_bear: true, bear_score: 0.95, person_score: 0.0, error: nil)
    @verdict = BearDetectorClient::Verdict.new(is_bear:, bear_score:, person_detected: person_score >= 0.2, person_score:,
                                               runner_up: "dog", runner_up_score: 0.1)
    @error = error
    @calls = 0
  end

  def detect(bytes)
    @calls += 1
    raise @error if @error
    raise "detector got the original, not a WebP" unless PhotoUpload.sniff(bytes) == :webp
    @verdict
  end
end

module SignInHelper
  def mock_sso(provider, uid)
    OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(provider: provider.to_s, uid:)
  end

  def sign_in_with(provider)
    post "/auth/#{provider}"
    follow_redirect!
  end

  def sign_in_as(user, provider: :github)
    uid = "uid-#{user.id}"
    user.identities.find_or_create_by!(provider: provider.to_s, uid:)
    mock_sso(provider, uid)
    sign_in_with(provider)
  end

  def session_json
    get "/api/session"
    response.parsed_body
  end

  # Like the SPA: read the CSRF token from the session endpoint, send it as a header.
  # Params as a hash or keywords; multipart: true for file uploads.
  def api(method, path, params = {}, multipart: false, **more)
    token = session_json["csrf_token"]
    send(method, path, params: params.merge(more), headers: { "X-CSRF-Token" => token }, as: (multipart ? nil : :json))
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper

  setup { OmniAuth.config.test_mode = true }
  teardown do
    OmniAuth.config.mock_auth.clear
    OmniAuth.config.test_mode = false
  end
end

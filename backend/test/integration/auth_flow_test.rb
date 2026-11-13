require "test_helper"

class AuthFlowTest < ActionDispatch::IntegrationTest
  setup { mock_sso(:github, "gh-123") }

  test "new account: SSO, then nickname, then signed in" do
    sign_in_with(:github)
    assert_redirected_to "/welcome"
    assert session_json["pending_signup"]
    assert_nil session_json["user"]

    api :post, "/api/signup", nickname: "otis_superfan"
    assert_response :created
    assert_equal "otis_superfan", response.parsed_body.dig("user", "nickname")

    body = session_json
    assert_equal "otis_superfan", body.dig("user", "nickname")
    assert_equal [ "github" ], body["linked_providers"]
    assert_not body["pending_signup"]

    identity = Identity.last
    assert_equal [ "github", "gh-123" ], [ identity.provider, identity.uid ]
  end

  test "returning account signs straight in" do
    user = User.create!(nickname: "grizzwald")
    user.identities.create!(provider: "github", uid: "gh-123")

    sign_in_with(:github)
    assert_redirected_to "/"
    assert_equal "grizzwald", session_json.dig("user", "nickname")
  end

  test "signup is rejected without a pending SSO identity" do
    api :post, "/api/signup", nickname: "sneaky_bear"
    assert_response :unprocessable_entity
    assert_equal 0, User.count
  end

  test "signup returns nickname errors" do
    User.create!(nickname: "taken_bear")
    sign_in_with(:github)

    api :post, "/api/signup", nickname: "Taken_Bear"
    assert_response :unprocessable_entity
    assert_equal [ "Taken. Another bear watcher got there first." ], response.parsed_body.dig("errors", "nickname")
  end

  test "nickname check gives live feedback during signup" do
    sign_in_with(:github)

    get "/api/nicknames/check", params: { nickname: "ab" }
    assert_equal({ "available" => false, "message" => "Use at least 3 characters." }, response.parsed_body)

    get "/api/nicknames/check", params: { nickname: "fresh_bear" }
    assert_equal({ "available" => true, "message" => nil }, response.parsed_body)
  end

  test "banned users see their ban reason" do
    user = User.create!(nickname: "troll_bear_99")
    user.identities.create!(provider: "github", uid: "gh-123")
    user.ban!("Uploaded photos of people instead of bears.")

    sign_in_with(:github)
    body = session_json
    assert body.dig("user", "banned")
    assert_equal "Uploaded photos of people instead of bears.", body.dig("user", "ban_reason")
  end

  test "a signed-in user can link a second provider" do
    user = User.create!(nickname: "grizzwald")
    user.identities.create!(provider: "github", uid: "gh-123")
    sign_in_with(:github)

    mock_sso(:google_oauth2, "google-456")
    sign_in_with(:google_oauth2)
    assert_redirected_to "/profile?linked=google_oauth2"
    assert_equal %w[github google_oauth2], user.identities.order(:provider).pluck(:provider)

    # Signing in with the linked Google account reaches the same user.
    api :delete, "/api/session"
    sign_in_with(:google_oauth2)
    assert_equal "grizzwald", session_json.dig("user", "nickname")
  end

  test "an SSO account linked to someone else can't be linked again" do
    other = User.create!(nickname: "other_bear")
    other.identities.create!(provider: "google_oauth2", uid: "google-456")
    me = User.create!(nickname: "grizzwald")
    me.identities.create!(provider: "github", uid: "gh-123")
    sign_in_with(:github)

    mock_sso(:google_oauth2, "google-456")
    sign_in_with(:google_oauth2)
    assert_redirected_to "/profile?link_error=taken"
    assert_equal [ "github" ], me.identities.pluck(:provider)
  end

  test "writes without a CSRF token are rejected" do
    sign_in_with(:github)
    post "/api/signup", params: { nickname: "otis_superfan" }, as: :json
    assert_response :unprocessable_entity
    assert_equal "invalid_csrf", response.parsed_body["error"]
  end

  test "sign out clears the session" do
    user = User.create!(nickname: "grizzwald")
    user.identities.create!(provider: "github", uid: "gh-123")
    sign_in_with(:github)

    api :delete, "/api/session"
    assert_response :no_content
    assert_nil session_json["user"]
  end
end

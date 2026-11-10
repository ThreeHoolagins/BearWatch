# Which SSO providers are switched on. A provider is enabled when its client
# id is configured; the developer provider exists only in development.
module OmniauthProviders
  def self.google
    [ ENV["GOOGLE_CLIENT_ID"].presence || test_value, ENV["GOOGLE_CLIENT_SECRET"].presence || test_value ]
  end

  def self.github
    [ ENV["GITHUB_CLIENT_ID"].presence || test_value, ENV["GITHUB_CLIENT_SECRET"].presence || test_value ]
  end

  def self.developer?
    Rails.env.development?
  end

  def self.enabled
    list = []
    list << "google_oauth2" if google.first
    list << "github" if github.first
    list << "developer" if developer?
    list
  end

  def self.test_value
    "test" if Rails.env.test?
  end
end

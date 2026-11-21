module Api
  # Finishes sign-up after an SSO callback for a new account: the person
  # picks a nickname and we create the user and its first identity together.
  class SignupsController < ApplicationController
    rate_limit to: 20, within: 10.minutes, only: :create

    PROVIDER_NAMES = { "google_oauth2" => "Google", "github" => "GitHub" }.freeze

    def create
      pending = pending_identity
      return render json: { error: "no_pending_signup" }, status: :unprocessable_entity unless pending

      user = User.new(nickname: params[:nickname].to_s)
      User.transaction do
        user.save!
        user.identities.create!(provider: pending["provider"], uid: pending["uid"])
      end

      sign_in(user)
      announce(user, pending["provider"])
      render json: { user:, csrf_token: form_authenticity_token }, status: :created
    rescue ActiveRecord::RecordInvalid
      render json: { errors: { nickname: user.errors.where(:nickname).map(&:message) } }, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotUnique
      # Lost a race with someone registering the same nickname.
      render json: { errors: { nickname: [ "Taken. Another bear watcher got there first." ] } }, status: :unprocessable_entity
    end

    private

    # Lets the ranger know on Discord whenever someone new joins.
    def announce(user, provider)
      return unless DiscordAlertJob.enabled?

      site = ENV["APP_HOST"].presence || "localhost"
      DiscordAlertJob.perform_later(":bear: New bear watcher: `#{user.nickname}` signed up with #{PROVIDER_NAMES.fetch(provider, provider)} (#{site}, #{User.count} total)")
    end
  end
end

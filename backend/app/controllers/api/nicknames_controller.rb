module Api
  # Live validation for the nickname field during sign-up.
  class NicknamesController < ApplicationController
    rate_limit to: 60, within: 1.minute, only: :check

    def check
      return render json: { error: "no_pending_signup" }, status: :unprocessable_entity unless pending_identity

      user = User.new(nickname: params[:nickname].to_s)
      user.valid?(:create)
      message = user.errors.where(:nickname).first&.message
      render json: { available: message.nil?, message: }
    end
  end
end

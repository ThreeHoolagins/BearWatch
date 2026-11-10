module Api
  class SessionsController < ApplicationController
    def show
      render json: {
        csrf_token: form_authenticity_token,
        user: current_user,
        linked_providers: current_user ? current_user.identities.pluck(:provider) : [],
        pending_signup: pending_identity.present?,
        providers: OmniauthProviders.enabled
      }
    end

    def destroy
      reset_session
      head :no_content
    end
  end
end

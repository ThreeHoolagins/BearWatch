module Api
  module Admin
    # The Ranger Station: everything here needs a signed-in, unbanned admin.
    class BaseController < ApplicationController
      before_action :require_admin!

      private
        def render_errors(record)
          render json: { error: "invalid", message: record.errors.full_messages.first }, status: :unprocessable_entity
        end
    end
  end
end

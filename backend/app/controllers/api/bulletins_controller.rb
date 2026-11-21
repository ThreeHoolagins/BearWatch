module Api
  # The house notices the feeds mix in between posts.
  class BulletinsController < ApplicationController
    before_action :authenticate!

    def index
      render json: { bulletins: Bulletin.live }
    end
  end
end

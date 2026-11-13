module Api
  # The current Fat Bear Week champion card, shown beside the feeds.
  class ChampionsController < ApplicationController
    before_action :authenticate!

    def show
      render json: { champion: FatBearChampion.includes(post: { user: :avatar_post }).current }
    end
  end
end

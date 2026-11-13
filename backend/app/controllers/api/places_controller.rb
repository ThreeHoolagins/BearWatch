module Api
  # Place suggestions for the post form. Coordinates come back already rounded
  # to ~11 km; the browser location sent to /reverse is used once and not saved.
  class PlacesController < ApplicationController
    before_action :authenticate!
    rate_limit to: 60, within: 1.minute, by: -> { current_user.id }

    def search
      query = params[:q].to_s.squish.first(80)
      return render json: { places: [] } if query.length < 2

      render json: { places: PlaceSearch.new.search(query).map(&:to_h) }
    rescue PlaceSearch::Unavailable
      render json: { error: "places_unavailable" }, status: :service_unavailable
    end

    def reverse
      latitude = Float(params[:lat], exception: false)
      longitude = Float(params[:lng], exception: false)
      unless latitude&.between?(-90, 90) && longitude&.between?(-180, 180)
        return render json: { error: "bad_coordinates" }, status: :unprocessable_entity
      end

      place = PlaceSearch.new.reverse(latitude.round(2), longitude.round(2))
      render json: { place: place&.to_h }
    rescue PlaceSearch::Unavailable
      render json: { error: "places_unavailable" }, status: :service_unavailable
    end
  end
end

module Api
  module Admin
    # The Fat Bear Week champion card: from a Bear Watch post, or an outside
    # photo with a credit and link.
    class ChampionsController < BaseController
      FIELDS = %i[bear_name bear_number blurb credit link_url link_text].freeze

      def show
        champion = FatBearChampion.find_by(year: params[:year]) || FatBearChampion.current
        render json: { champion: }
      end

      # Creates or replaces the card for a year. Multipart when uploading a photo.
      def update
        champion = FatBearChampion.find_or_initialize_by(year: params[:year])
        old_photo = [ champion.image_key, champion.image_storage ] if champion.image_key
        champion.assign_attributes(params.permit(*FIELDS).to_h.transform_values(&:to_s))
        champion.updated_by = current_user

        if params[:source] == "post"
          post = Post.published.find_by(id: params[:post_id])
          return render json: { error: "invalid", message: "Pick a published Bear Watch post." }, status: :unprocessable_entity unless post
          champion.assign_attributes(post:, image_key: nil, image_storage: nil, image_width: nil, image_height: nil,
                                     image_bytes: nil, credit: nil, link_url: nil, link_text: nil)
        elsif params[:photo].present?
          stored = ChampionPhoto.store!(params[:photo])
          champion.assign_attributes(post: nil, image_key: stored.key, image_storage: stored.storage,
                                     image_width: stored.width, image_height: stored.height, image_bytes: stored.bytes)
        else
          champion.post = nil # keep the outside photo already on the card
        end

        if champion.save
          DeletePhotoJob.perform_later(*old_photo) if old_photo && old_photo.first != champion.image_key
          render json: { champion: }
        else
          DeletePhotoJob.perform_later(stored.key, stored.storage) if stored
          render_errors(champion)
        end
      rescue ChampionPhoto::Rejected => error
        render json: { error: "invalid", message: error.message }, status: :unprocessable_entity
      end
    end
  end
end

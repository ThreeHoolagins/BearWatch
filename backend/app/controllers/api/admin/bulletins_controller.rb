module Api
  module Admin
    # House notices shown between posts in the feeds, cycling in position order.
    class BulletinsController < BaseController
      FIELDS = %i[title body kind link_url link_text sponsor active position].freeze

      def index
        render json: { bulletins: Bulletin.ordered }
      end

      def create
        save Bulletin.new, :created
      end

      def update
        save Bulletin.find(params[:id]), :ok
      end

      def destroy
        Bulletin.find(params[:id]).destroy!
        head :no_content
      end

      private
        # Multipart when uploading a photo; `remove_photo` takes it off.
        def save(bulletin, status)
          old_photo = [ bulletin.image_key, bulletin.image_storage ] if bulletin.image_key
          bulletin.assign_attributes(params.permit(*FIELDS))
          bulletin.updated_by = current_user

          if params[:photo].present?
            stored = ChampionPhoto.store!(params[:photo], prefix: "bulletin")
            bulletin.assign_attributes(image_key: stored.key, image_storage: stored.storage, image_width: stored.width,
                                       image_height: stored.height, image_bytes: stored.bytes)
          elsif ActiveModel::Type::Boolean.new.cast(params[:remove_photo])
            bulletin.assign_attributes(image_key: nil, image_storage: nil, image_width: nil, image_height: nil, image_bytes: nil)
          end

          if bulletin.save
            DeletePhotoJob.perform_later(*old_photo) if old_photo && old_photo.first != bulletin.image_key
            render json: { bulletin: }, status:
          else
            DeletePhotoJob.perform_later(stored.key, stored.storage) if stored
            render_errors(bulletin)
          end
        rescue ChampionPhoto::Rejected => error
          render json: { error: "invalid", message: error.message }, status: :unprocessable_entity
        end
    end
  end
end

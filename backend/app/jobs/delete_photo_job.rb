require "aws-sdk-s3"

# Removes a stored photo after its post or champion card is deleted. Runs in
# the web process ("online" queue) because R2 needs internet access.
class DeletePhotoJob < ApplicationJob
  queue_as :online

  retry_on Aws::S3::Errors::ServiceError, Seahorse::Client::NetworkingError, wait: 1.minute, attempts: 5

  def perform(key, storage)
    if storage == "r2"
      R2Client.new.delete(PhotoStorage.r2_key(key)) # deletes are free on R2
    else
      FileUtils.rm_f(PhotoStorage.media_path(key))
    end
  end
end

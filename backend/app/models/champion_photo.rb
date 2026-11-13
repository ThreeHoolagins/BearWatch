# Stores an outside photo for the Fat Bear Week champion card. Only admins can
# upload one, so it's processed right away in the web request (same checks and
# metadata-stripping re-encode as posts, no bear check), rather than queued.
class ChampionPhoto
  Stored = Data.define(:key, :storage, :width, :height, :bytes)

  class Rejected < StandardError; end

  def self.store!(file)
    upload = PhotoUpload.new(file)
    raise Rejected, upload.errors.full_messages.first unless upload.valid?
    raise Rejected, "That photo is over 50 megapixels. Try a smaller one." if ImageTools.too_large?(file.tempfile.path)

    key = "champion-#{PhotoStorage.new_key}"
    local = PhotoStorage.media_path(key)
    width, height = ImageTools.to_webp(file.tempfile.path, local)
    bytes = local.size

    if PhotoStorage.r2?
      if StorageQuota.exhausted?(bytes)
        FileUtils.rm_f(local)
        raise Rejected, StorageQuota::OUT_OF_HONEY
      end
      R2Client.new.put_webp(PhotoStorage.r2_key(key), local)
      FileUtils.rm_f(local)
      Stored.new(key:, storage: "r2", width:, height:, bytes:)
    else
      Stored.new(key:, storage: "local", width:, height:, bytes:)
    end
  rescue ImageTools::Unreadable
    FileUtils.rm_f(local) if local
    raise Rejected, "We couldn't open that photo. Try a JPG or PNG."
  end
end

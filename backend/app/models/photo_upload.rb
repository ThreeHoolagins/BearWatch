# First line of defence for an uploaded photo, checked in the web request
# before anything is queued: size, file extension, and the file's actual
# first bytes ("magic bytes") must agree. Nothing here decodes the image;
# that only happens in the worker, which has no internet access.
class PhotoUpload
  include ActiveModel::Validations

  MAX_BYTES = 12.megabytes

  # Extension -> the format its magic bytes must show.
  EXTENSIONS = {
    "jpg" => :jpeg, "jpeg" => :jpeg,
    "png" => :png,
    "webp" => :webp,
    "heic" => :heif, "heif" => :heif
  }.freeze

  HEIF_BRANDS = %w[heic heix hevc hevx heim heis mif1 msf1].freeze

  attr_reader :file

  validate :check_file

  def initialize(file)
    @file = file
  end

  def self.sniff(bytes)
    bytes = bytes.to_s.b
    if bytes.start_with?("\xFF\xD8\xFF".b) then :jpeg
    elsif bytes.start_with?("\x89PNG\r\n\x1A\n".b) then :png
    elsif bytes[0, 4] == "RIFF" && bytes[8, 4] == "WEBP" then :webp
    elsif bytes[4, 4] == "ftyp" && HEIF_BRANDS.include?(bytes[8, 4]) then :heif
    end
  end

  private
    def check_file
      unless file.respond_to?(:tempfile) && file.respond_to?(:original_filename)
        return errors.add(:base, "Choose a photo to upload.")
      end
      return errors.add(:base, "That photo is over 12 MB. Try a smaller one.") if file.size > MAX_BYTES
      return errors.add(:base, "That photo is empty.") if file.size.zero?

      expected = EXTENSIONS[File.extname(file.original_filename.to_s).delete_prefix(".").downcase]
      return errors.add(:base, "Use a JPG, PNG, WebP or HEIC photo.") unless expected

      actual = self.class.sniff(File.binread(file.tempfile.path, 16))
      errors.add(:base, "That file isn't the kind of image its name says it is.") unless actual == expected
    end
end

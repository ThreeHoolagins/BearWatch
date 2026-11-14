# Real bear photos for development seeds, kept in db/seeds/photos. All are
# public domain (mostly NPS and US Fish & Wildlife Service) or CC0, from
# Wikimedia Commons; photos.yml lists each one's source, author and license.
#
# Each photo already passed the detector (a bear, no person), and its bear box
# is saved in photos.yml, so seeding needs neither the network nor the detector.
module SeedPhotos
  DIR = Pathname(__dir__).join("photos")
  KINDS = %w[brown black polar panda].freeze

  Photo = Data.define(:path, :kind, :width, :height, :bear_score, :bear_box)

  module_function

  def all
    @all ||= YAML.load_file(DIR.join("photos.yml")).map do |entry|
      Photo.new(path: DIR.join(entry["file"]), kind: entry["kind"], width: entry["width"], height: entry["height"],
                bear_score: entry["bear_score"], bear_box: entry["bear_box"])
    end
  end

  # Deals photos of the given kinds like cards from a shuffled deck, so
  # repeats only start once every matching photo has been used.
  def deal(kinds, rng)
    @decks ||= {}
    deck = (@decks[kinds] ||= [])
    deck.replace(all.select { kinds.include?(_1.kind) }.shuffle(random: rng)) if deck.empty?
    deck.shift or raise "No seed photos of kind #{kinds.inspect}"
  end

  # Avatar crop centred on the bear and zoomed to fit it, like the avatar
  # picker's starting point (frontend/src/components/AvatarPicker.tsx).
  def avatar_crop(photo)
    bx, by, bw, bh = photo.bear_box
    fit = [ photo.width, photo.height ].min / [ bw * photo.width, bh * photo.height, 1 ].max
    { avatar_zoom: (fit * 0.95).clamp(1.0, 4.0).round(2), avatar_x: bx, avatar_y: by }
  end
end

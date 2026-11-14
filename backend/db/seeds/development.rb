require_relative "seed_photos"

module DevelopmentSeeds
  # name, latitude, longitude, kinds of bear you might see there
  PLACES = {
    katmai: [ "Katmai National Park, AK", 58.5, -155.0, %w[brown] ],
    denali: [ "Denali National Park, AK", 63.3, -150.5, %w[brown] ],
    yellowstone: [ "Yellowstone National Park, WY", 44.6, -110.5, %w[brown black] ],
    teton: [ "Grand Teton National Park, WY", 43.8, -110.7, %w[brown black] ],
    rmnp: [ "Rocky Mountain National Park, CO", 40.3, -105.7, %w[black] ],
    estes: [ "Estes Park, CO", 40.4, -105.5, %w[black] ],
    fort_collins: [ "Fort Collins, CO", 40.6, -105.1, %w[black] ],
    steamboat: [ "Steamboat Springs, CO", 40.5, -106.8, %w[black] ],
    durango: [ "Durango, CO", 37.3, -107.9, %w[black] ],
    glacier: [ "Glacier National Park, MT", 48.7, -113.8, %w[brown black] ],
    smokies: [ "Great Smoky Mountains National Park, TN", 35.6, -83.5, %w[black] ],
    yosemite: [ "Yosemite National Park, CA", 37.9, -119.5, %w[black] ],
    banff: [ "Banff, Alberta, Canada", 51.2, -115.6, %w[brown black] ],
    london: [ "London, England, United Kingdom", 51.5, -0.1, %w[brown black] ]
  }.freeze

  # Within 500 miles of Fort Collins: rmnp, estes, fort_collins, steamboat,
  # durango, teton, yellowstone. Everything else only shows up in Following
  # and on profiles, which is handy for testing the radius.
  #
  # paddington has >30 posts (profile "Show more") and enough near Fort
  # Collins to need a second page on Global. ted has none (empty profile).
  # kind: overrides the place's kinds of bear (polar bears in Banff, sure).
  CAST = [
    { nick: "smokey_bear", places: %i[rmnp fort_collins], posts: 4, avatar: true, ranger: true },
    { nick: "paddington", places: %i[rmnp estes fort_collins steamboat london], posts: 34, avatar: true },
    { nick: "winnie_the_pooh", places: %i[estes rmnp], posts: 5, avatar: true },
    { nick: "baloo", places: %i[smokies yosemite], posts: 4, avatar: true },
    { nick: "yogi_bear", places: %i[yellowstone teton], posts: 6, avatar: true },
    { nick: "fozzie_bear", places: %i[durango fort_collins], posts: 3 },
    { nick: "little_john", places: %i[glacier], posts: 2 },
    { nick: "teddy_ruxpin", places: %i[steamboat], posts: 2, avatar: true },
    { nick: "corduroy", places: %i[fort_collins], posts: 1 },
    { nick: "grumpy_bear", places: %i[denali], posts: 2 },
    { nick: "tenderheart_bear", places: %i[estes], posts: 2, avatar: true },
    { nick: "kenai", places: %i[katmai denali], posts: 4, avatar: true },
    { nick: "koda", places: %i[katmai], posts: 3 },
    { nick: "po_the_panda", places: %i[yosemite], posts: 2, kind: "panda" },
    { nick: "grizz", places: %i[yosemite teton], posts: 3, avatar: true },
    { nick: "panda", places: %i[yosemite], posts: 1, kind: "panda" },
    { nick: "ice_bear", places: %i[denali banff], posts: 3, kind: "polar" },
    { nick: "gentle_ben", places: %i[smokies], posts: 2 },
    { nick: "rupert_bear", places: %i[london], posts: 2 },
    { nick: "iorek_byrnison", places: %i[banff denali], posts: 2, avatar: true, kind: "polar" },
    { nick: "bungle", places: %i[london], posts: 1 },
    { nick: "pudsey_bear", places: %i[london], posts: 1 },
    { nick: "barney_bear", places: %i[glacier], posts: 2 },
    { nick: "ted", places: %i[fort_collins], posts: 0 },
    { nick: "lotso", places: %i[fort_collins], posts: 2, banned: "Kept trying to take over the daycare." }
    # (boo_boo would be here, but the nickname filter spots "boob" in "booboo".)
  ].freeze

  WINS = { 2023 => "baloo", 2024 => "yogi_bear", 2025 => "winnie_the_pooh" }.freeze

  module_function

  def nicknames = CAST.map { _1[:nick] }

  def run
    rng = Random.new(1014) # same pictures and follows every time
    users = CAST.filter_map { |bear| seed_user(bear) }
    seeded = users.select { |user, created| created }.map(&:first)
    all = users.map(&:first)

    count = 0
    CAST.each do |bear|
      user = all.find { _1.nickname == bear[:nick] }
      next unless user && seeded.include?(user)

      posts = Array.new(bear[:posts]) do |i|
        seed_post(user, PLACES.fetch(bear[:places][i % bear[:places].size]), bear[:kind], rng)
      end
      count += posts.size
      set_avatar(user, posts.first) if bear[:avatar] && posts.any?
      user.ban!(bear[:banned]) if bear[:banned]
    end

    seed_follows(all, rng)
    follow_from_me(all)
    seed_wins
    seed_champion

    puts "Seeded #{seeded.size} bears and #{count} posts (#{all.size - seeded.size} already existed)."
    puts "Sign in with \"Developer sign-in\" using a nickname as the name, e.g. paddington."
  end

  # Returns [user, created?]. Skips a nickname a real account already uses.
  def seed_user(bear)
    if (existing = User.find_by(nickname: bear[:nick]))
      return [ existing, false ] if existing.identities.exists?(provider: "developer", uid: bear[:nick])
      puts "Skipping #{bear[:nick]}: a real account already has that nickname."
      return
    end

    user = User.create!(nickname: bear[:nick], is_admin: bear[:ranger] || false,
                        created_at: rand(40..90).days.ago)
    user.identities.create!(provider: "developer", uid: bear[:nick])
    [ user, true ]
  end

  def seed_post(user, place, kind, rng)
    name, lat, lng, kinds = place
    photo = SeedPhotos.deal(kind ? [ kind ] : kinds, rng)
    key = PhotoStorage.new_key
    path = PhotoStorage.media_path(key)
    FileUtils.cp(photo.path, path)
    at = rng.rand(0.0..40.0).days.ago
    bx, by, bw, bh = photo.bear_box

    # Seed photos stay on local disk (served at /media) even when R2 is on,
    # so seeding never touches the bucket or the free-tier cap.
    user.posts.create!(
      status: "published", storage: "local", image_key: key, image_bytes: path.size, width: photo.width, height: photo.height,
      place_name: name, latitude: lat + rng.rand(-0.3..0.3), longitude: lng + rng.rand(-0.3..0.3),
      bear_score: photo.bear_score, bear_x: bx, bear_y: by, bear_w: bw, bear_h: bh,
      created_at: at, updated_at: at
    ).tap { |post| post.define_singleton_method(:seed_photo) { photo } }
  end

  def set_avatar(user, post)
    user.update!(avatar_post: post, **SeedPhotos.avatar_crop(post.seed_photo))
  end

  def seed_follows(users, rng)
    active = users.reject(&:banned?)
    active.each do |user|
      others = active - [ user ]
      picks = user.nickname == "smokey_bear" ? others : others.sample(rng.rand(3..7), random: rng)
      picks.each { |followee| user.following_links.find_or_create_by!(followee:) }
    end
  end

  # ME=your_nickname makes your own account follow a handful of seed bears,
  # so your Following feed has something in it.
  def follow_from_me(users)
    return if ENV["ME"].blank?

    me = User.find_by(nickname: ENV["ME"])
    return puts("ME=#{ENV["ME"]}: no account with that nickname.") unless me

    %w[paddington yogi_bear kenai winnie_the_pooh baloo grizz].each do |nick|
      bear = users.find { _1.nickname == nick }
      me.following_links.find_or_create_by!(followee: bear) if bear
    end
    puts "#{me.nickname} now follows some seed bears."
  end

  def seed_wins
    ranger = User.find_by(nickname: "smokey_bear")
    WINS.each do |year, nick|
      next if FatBearWin.exists?(year:)

      post = User.find_by(nickname: nick)&.posts&.published&.order(:created_at)&.first
      FatBearWin.create!(post:, year:, awarded_by: ranger) if post
    end
  end

  # Only if there's no champion card yet, so a real one is never replaced.
  def seed_champion
    return if FatBearChampion.exists?

    winner = FatBearWin.order(year: :desc).first or return
    FatBearChampion.create!(year: winner.year, post: winner.post, bear_name: winner.post.user.nickname.titleize,
                            blurb: "The roundest bear on the trail this year.", updated_by: User.find_by(nickname: "smokey_bear"))
  end

  # Removes only the seed bears (accounts that sign in with the developer
  # login under a seed nickname), including their photos.
  def remove!
    users = User.joins(:identities).where(nickname: nicknames, identities: { provider: "developer" }).distinct
    count = users.count
    FatBearChampion.where(post_id: Post.where(user_id: users.select(:id)).select(:id)).destroy_all
    users.find_each do |user|
      user.posts.each { |post| FileUtils.rm_f(PhotoStorage.media_path(post.image_key)) if post.storage == "local" && post.image_key }
      user.destroy!
    end
    puts "Removed #{count} seed bears."
  end
end

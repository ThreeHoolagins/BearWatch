# Development data: a cast of pop-culture bears with posts, follows, bear-face
# avatars, Fat Bear Week wins and one banned troublemaker.
#
#   docker compose exec web bin/rails db:seed                # add the seed bears (safe to re-run)
#   docker compose exec web bin/rails bearwatch:seed:reset   # remove them and seed again
#
# Sign in as any of them with "Developer sign-in" and their nickname as the
# name, e.g. "paddington". Your own accounts are never touched.

unless Rails.env.development? || ENV["ALLOW_SEEDS"] == "1"
  abort "Seeds are for development only. (Set ALLOW_SEEDS=1 to override.)"
end

require_relative "seeds/development"
DevelopmentSeeds.run

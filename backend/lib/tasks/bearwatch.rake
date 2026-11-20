# Admin chores until the admin panel exists (Phase 4). Examples:
#   bin/rails "bearwatch:admin[grizzwald]"
#   bin/rails "bearwatch:ban[troll_bear_99,Uploaded photos of people instead of bears.]"
#   bin/rails "bearwatch:unban[troll_bear_99]"
namespace :bearwatch do
  desc "Give a user admin rights"
  task :admin, [ :nickname ] => :environment do |_, args|
    user = User.find_by!(nickname: args[:nickname])
    user.update!(is_admin: true)
    puts "#{user.nickname} is now an admin."
  end

  desc "Ban a user with a reason they will see when signing in"
  task :ban, [ :nickname, :reason ] => :environment do |_, args|
    abort "A reason is required." if args[:reason].blank?
    user = User.find_by!(nickname: args[:nickname])
    user.ban!(args[:reason])
    puts "#{user.nickname} is banned: #{user.ban_reason}"
  end

  desc "Lift a ban"
  task :unban, [ :nickname ] => :environment do |_, args|
    user = User.find_by!(nickname: args[:nickname])
    user.unban!
    puts "#{user.nickname} is no longer banned."
  end
end

namespace :bearwatch do
  namespace :storage do
    desc "Show R2 usage against the free-tier cap"
    task status: :environment do
      puts "Storage backend: #{PhotoStorage.r2? ? "Cloudflare R2 (#{ENV["R2_BUCKET"]})" : "local disk"}"
      puts StorageQuota.usage.summary
      month = StorageMonth.current
      puts "Last bucket measurement: #{month.observed_at || "never"}"
      puts "Out-of-honey Discord alert this month: #{month.alerted_at || "not sent"}"
      puts StorageQuota.exhausted? ? "Uploads: PAUSED (out of honey)" : "Uploads: open"
    end

    desc "Measure the bucket now (normally runs every 6 hours)"
    task check: :environment do
      CheckStorageUsageJob.perform_now
      Rake::Task["bearwatch:storage:status"].invoke
    end

    desc "Allow another out-of-honey alert this month"
    task reset_alert: :environment do
      StorageMonth.current.update!(alerted_at: nil)
      puts "Alert reset."
    end
  end
end

namespace :bearwatch do
  namespace :seed do
    desc "Development: remove the seed bears (and their photos), then seed again. Your own accounts are kept."
    task reset: :environment do
      abort "Seeds are for development only." unless Rails.env.development? || ENV["ALLOW_SEEDS"] == "1"
      require Rails.root.join("db/seeds/development")
      DevelopmentSeeds.remove!
      Rake::Task["db:seed"].invoke
    end
  end
end

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

class CreateBulletins < ActiveRecord::Migration[8.0]
  def change
    # House notices shown between posts in the feeds (one every 10 posts,
    # cycling in position order): invites, Ko-fi, announcements.
    create_table :bulletins do |t|
      t.string :title, null: false, limit: 80
      t.string :body, null: false, limit: 300
      t.string :kind, null: false, limit: 8, default: "link" # "link" opens link_url; "share" shares Bear Watch
      t.string :link_url, limit: 500
      t.string :link_text, null: false, limit: 40
      t.string :sponsor, limit: 60 # set for paid placements; the card is labeled "Sponsored"
      t.string :image_key, limit: 64 # optional photo, stored like the champion card's
      t.string :image_storage, limit: 8
      t.integer :image_width
      t.integer :image_height
      t.integer :image_bytes
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.references :updated_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :bulletins, %i[active position]

    reversible do |dir|
      dir.up do
        now = connection.quote(Time.current)
        execute <<~SQL
          INSERT INTO bulletins (title, body, kind, link_url, link_text, image_key, image_storage, image_width, image_height,
                                 active, position, created_at, updated_at) VALUES
          ('Know a bear enthusiast?',
           'Bear Watch gets better with every pair of eyes on the trail. Invite the friend who always stops the car to take a picture of a bear.',
           'share', NULL, 'Invite a friend', 'bearwatch-logo.svg', 'static', 600, 600, TRUE, 1, #{now}, #{now}),
          ('Help keep the lights on',
           'Bear Watch runs on a small server that is free for now. When the free hosting runs out, it only stays on if bear watchers chip in. If it has brought you joy, a coffee helps keep it running.',
           'link', 'https://ko-fi.com/bigolbearstudios', 'Support Bear Watch on Ko-fi', 'bigolbearstudios-logo.png', 'static', 1080, 744,
           TRUE, 2, #{now}, #{now})
        SQL
      end
    end
  end
end

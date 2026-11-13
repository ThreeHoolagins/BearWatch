class CreateFollowsAndAvatars < ActiveRecord::Migration[8.0]
  def change
    create_table :follows do |t|
      t.references :follower, null: false, foreign_key: { to_table: :users }
      t.references :followee, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :follows, [ :follower_id, :followee_id ], unique: true

    # Avatar: a crop of one of the user's own photos. Zoom 1-4; x/y are the
    # point (0-1 across the photo) shown at the centre of the circle.
    add_reference :users, :avatar_post, foreign_key: { to_table: :posts, on_delete: :nullify }
    add_column :users, :avatar_zoom, :float
    add_column :users, :avatar_x, :float
    add_column :users, :avatar_y, :float

    # Where the detector found the bear (centre and size, 0-1 of the photo),
    # so the avatar picker can start on the bear.
    add_column :posts, :bear_x, :float
    add_column :posts, :bear_y, :float
    add_column :posts, :bear_w, :float
    add_column :posts, :bear_h, :float

    # Global feed: published posts near a point.
    add_index :posts, [ :status, :latitude, :longitude ]
  end
end

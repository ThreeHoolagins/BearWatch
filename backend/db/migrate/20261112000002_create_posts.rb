class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true
      # processing -> published | rejected | failed
      t.string :status, null: false, default: "processing", limit: 16
      # Random name of the processed WebP; set once published.
      t.string :image_key, limit: 64
      t.integer :width
      t.integer :height
      t.string :place_name, null: false, limit: 120
      # Rounded to one decimal place (~11 km) before saving. Exact spots are never stored.
      t.decimal :latitude, precision: 4, scale: 1, null: false
      t.decimal :longitude, precision: 4, scale: 1, null: false
      t.float :bear_score
      t.string :failure_reason, limit: 32
      t.timestamps
    end
    add_index :posts, [ :status, :created_at ]
    add_index :posts, [ :user_id, :created_at ]
    add_index :posts, :image_key, unique: true
  end
end

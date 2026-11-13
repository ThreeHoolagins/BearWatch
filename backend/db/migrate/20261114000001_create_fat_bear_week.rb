class CreateFatBearWeek < ActiveRecord::Migration[8.0]
  def change
    # A Fat Bear Week win, awarded by hand to the post that matches the real
    # (off-platform) winner. One winner per year.
    create_table :fat_bear_wins do |t|
      t.references :post, null: false, foreign_key: { on_delete: :cascade }
      t.integer :year, null: false
      t.references :awarded_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :fat_bear_wins, :year, unique: true

    # The champion card shown beside the feeds. Usually the real winner was
    # never posted here, so it can use an outside photo with a credit and link.
    create_table :fat_bear_champions do |t|
      t.integer :year, null: false
      t.string :bear_name, null: false, limit: 60
      t.string :bear_number, limit: 10
      t.string :blurb, limit: 200
      t.references :post, foreign_key: { on_delete: :nullify } # a Bear Watch post, or...
      t.string :image_key, limit: 64                            # ...an outside photo
      t.string :image_storage, limit: 8
      t.integer :image_width
      t.integer :image_height
      t.integer :image_bytes
      t.string :credit, limit: 150
      t.string :link_url, limit: 500
      t.string :link_text, limit: 80
      t.references :updated_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :fat_bear_champions, :year, unique: true
  end
end

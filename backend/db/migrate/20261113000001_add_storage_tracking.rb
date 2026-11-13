class AddStorageTracking < ActiveRecord::Migration[8.0]
  def change
    # Where the published WebP lives ("local" disk or "r2") and its size, so
    # we can add up exactly how much R2 storage we use.
    add_column :posts, :storage, :string, null: false, default: "local", limit: 8
    add_column :posts, :image_bytes, :integer

    # One row per calendar month of R2 usage (operation limits reset monthly).
    create_table :storage_months do |t|
      t.date :month, null: false
      t.bigint :class_a_ops, null: false, default: 0 # writes and lists we've made
      t.bigint :class_b_ops                          # reads, only if Cloudflare analytics is readable
      t.bigint :observed_bytes                       # bucket size from the last full listing
      t.datetime :observed_at
      t.datetime :alerted_at                         # "out of honey" email sent
      t.timestamps
    end
    add_index :storage_months, :month, unique: true
  end
end

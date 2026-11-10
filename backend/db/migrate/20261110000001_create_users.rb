class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      # utf8mb4_0900_ai_ci is case-insensitive, so the unique index also
      # stops "Grizz" and "grizz" from both existing.
      t.string :nickname, null: false, limit: 20
      t.boolean :is_admin, null: false, default: false
      t.datetime :banned_at
      t.string :ban_reason, limit: 500
      t.timestamps
    end
    add_index :users, :nickname, unique: true
  end
end

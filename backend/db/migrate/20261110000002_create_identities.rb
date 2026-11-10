# One row per linked SSO account. We store only the provider name and the
# provider's stable account id: no tokens, emails or names.
class CreateIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false, limit: 32
      t.string :uid, null: false
      t.timestamps
    end
    add_index :identities, [ :provider, :uid ], unique: true
    add_index :identities, [ :user_id, :provider ], unique: true
  end
end

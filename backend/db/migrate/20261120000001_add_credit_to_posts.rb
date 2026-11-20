class AddCreditToPosts < ActiveRecord::Migration[8.0]
  def change
    # Who took an archive photo and where it came from. Empty for bears
    # people upload themselves.
    add_column :posts, :credit, :string, limit: 200
    add_column :posts, :source_url, :string, limit: 500
  end
end

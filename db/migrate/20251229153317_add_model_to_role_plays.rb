class AddModelToRolePlays < ActiveRecord::Migration[8.1]
  def change
    add_column :role_plays, :model, :string, default: "gpt-4o", null: false
  end
end

class CreateRolePlays < ActiveRecord::Migration[8.1]
  def change
    create_table :role_plays do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.text :llm_instructions, null: false
      t.integer :duration_minutes, null: false
      t.text :recommended_for, null: false
      t.integer :category, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :role_plays, :name, unique: true
    add_index :role_plays, :category
    add_index :role_plays, :active
  end
end

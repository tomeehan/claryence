class ConvertRolePlayCategoryEnumToModel < ActiveRecord::Migration[8.1]
  CATEGORIES = {
    0 => "Communication",
    1 => "Team Management",
    2 => "Conflict Resolution",
    3 => "Performance Management",
    4 => "Leadership Development"
  }

  def up
    create_table :categories do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :categories, :name, unique: true

    add_reference :role_plays, :category, foreign_key: true, null: true

    # Minimal AR classes for data migration (locals to avoid constant assignment in method scope)
    category_model = Class.new(ActiveRecord::Base) { self.table_name = "categories" }
    role_play_model = Class.new(ActiveRecord::Base) { self.table_name = "role_plays" }

    # Seed categories from enum mapping
    CATEGORIES.values.each { |name| category_model.find_or_create_by!(name: name) }

    # Backfill role_plays.category_id using enum integer values
    say_with_time "Backfilling role_plays.category_id" do
      role_play_model.reset_column_information
      category_model.reset_column_information

      role_play_model.find_each do |rp|
        name = CATEGORIES[rp[:category]]
        next unless name
        cat = category_model.find_by!(name: name)
        rp.update_columns(category_id: cat.id)
      end
    end

    change_column_null :role_plays, :category_id, false
    add_index :role_plays, :category_id, if_not_exists: true
    remove_column :role_plays, :category, :integer
  end

  def down
    add_column :role_plays, :category, :integer, null: false, default: 0

    # Restore enum integers from categories by best‑effort name match
    role_play_model = Class.new(ActiveRecord::Base) { self.table_name = "role_plays" }
    category_model = Class.new(ActiveRecord::Base) { self.table_name = "categories" }

    say_with_time "Restoring role_plays.category enum integers" do
      role_play_model.reset_column_information
      category_model.reset_column_information
      role_play_model.find_each do |rp|
        if rp[:category_id]
          name = category_model.where(id: rp[:category_id]).limit(1).pluck(:name).first
          enum_val = CATEGORIES.invert[name] || 0
          rp.update_columns(category: enum_val)
        end
      end
    end

    remove_index :role_plays, :category_id, if_exists: true
    remove_reference :role_plays, :category, foreign_key: true
    drop_table :categories
  end
end

class AddActiveToKnowledges < ActiveRecord::Migration[8.1]
  def change
    add_column :knowledges, :active, :boolean, default: true, null: false
    add_index :knowledges, :active
  end
end


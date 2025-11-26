class CreateKnowledges < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledges do |t|
      t.text :content

      t.timestamps
    end
  end
end


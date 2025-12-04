class AddSummaryToKnowledges < ActiveRecord::Migration[8.1]
  def change
    add_column :knowledges, :summary, :string
  end
end

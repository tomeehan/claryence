class AddLlmContextToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :llm_context, :text
  end
end


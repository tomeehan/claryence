class MigrateSystemPromptToRichText < ActiveRecord::Migration[8.1]
  class SystemPrompt < ActiveRecord::Base
    self.table_name = "system_prompts"
  end

  def up
    SystemPrompt.find_each do |sp|
      body = sp[:content].to_s
      next if body.blank?
      ActionText::RichText.find_or_create_by!(record_type: "SystemPrompt", record_id: sp.id, name: "content") do |rt|
        rt.body = body
      end
    end
  end

  def down
    ActionText::RichText.where(record_type: "SystemPrompt", name: "content").delete_all
  end
end


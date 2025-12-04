class SeedClarySoulSystemPrompt < ActiveRecord::Migration[8.1]
  class SystemPrompt < ActiveRecord::Base
    self.table_name = "system_prompts"
  end

  def up
    SystemPrompt.find_or_create_by!(key: "clary_soul") do |sp|
      sp.content = "Clary soul system prompt - edit in admin"
    end
  end

  def down
    SystemPrompt.where(key: "clary_soul").delete_all
  end
end
